# خطة دمج Flutter مع Accounting Sync API v1

## 1. المرجع المعتمد

تمت مراجعة مشروع Flutter والوثائق التالية:

- `FLUTTER_SERVER_CONNECTION_AR.md`: المرجع الأعلى أولوية لعنوان الاتصال وإعداد Flutter.
- `API_CONTRACT_AR.md`: عقد HTTP والمصادقة والأجهزة والمزامنة والأخطاء.
- `EVENT_CATALOG_AR.md`: أنواع الأحداث وبنية كل `payload`.
- `openapi.yaml`: أشكال الطلبات والاستجابات القابلة للتوليد.
- `SERVER_DATABASE_SCHEMA_AR.md`: وصف قاعدة Spring/PostgreSQL الفعلية وحدود v1.

عنوان Flutter الإنتاجي المعتمد حصراً:

```text
https://accounting.alkhaleel-mosque.com/api/v1
```

القيم القديمة الموجودة داخل بعض نسخ العقود مهملة. لا يستخدم التطبيق عنوان IP قديمًا، أو منفذ الاختبار القديم، أو HTTP للإنتاج، أو مسار `/admin/`.

> ملاحظة: `supabase/schema.sql` أصبح مرجعاً تاريخياً فقط. الخادم الرسمي الحالي Spring/PostgreSQL مبني على Event Store، وليس سكيما Supabase القديمة ذات مزامنة الصفوف.

## 2. ما تم تنفيذه في هذه الدفعة

### إعداد الاتصال

- إضافة `ApiConfig` وقراءة `API_BASE_URL` بواسطة `String.fromEnvironment`.
- تعيين الدومين الإنتاجي الجديد كقيمة افتراضية.
- إزالة `server_link.dart` والإعداد الفارغ القديم.
- منع:
  - عنوان الخادم القديم.
  - المنفذ القديم.
  - HTTP خارج `localhost` والتطوير المحلي.
  - `/admin`.
  - الروابط المطلقة في استدعاءات `ApiClient`.
- تطبيع الشرطة المائلة الأخيرة.
- اختزال `/api/v1/api/v1` إلى نسخة واحدة.
- تطبيع مسارات الطلبات مثل `/api/v1/me` إلى `/me` قبل تمريرها إلى Dio.

### Dio وApiClient

- نقل إنشاء Dio بالكامل إلى `createAppDio()`؛ هذا هو مكان الإعداد الوحيد.
- الإعداد الحالي:
  - connect timeout: 15 ثانية.
  - send timeout: 30 ثانية.
  - receive timeout: 30 ثانية.
  - `Accept: application/json`.
  - `Content-Type: application/json`.
- إضافة ثوابت مسارات v1 في `ApiEndpoints`.
- منع تسجيل request/response bodies لتفادي تسريب كلمات المرور أو التوكنات.
- إصلاح إعادة الطلب بعد `401` حتى تستخدم access token الجديد فعلياً.
- منع حلقة refresh غير محدودة: refresh واحد، ثم retry واحد فقط.
- توسيع معالجة أخطاء الاتصال وقراءة حقل `message` من عقد الخطأ الجديد.

### المنصات

- إضافة صلاحية `INTERNET` إلى Android manifest الرئيسي، وبالتالي إلى Release أيضاً.
- لم تتم إضافة `usesCleartextTraffic`.
- لم تتم إضافة ATS exception إلى iOS.

## 3. الوضع الحالي للمشروع قبل ربط API

المشروع Offline-First ويكتب العمليات أولاً في SQLite. هذه نقطة متوافقة مع العقد، لكن صيغة المزامنة الحالية غير متوافقة.

الطبقات الحالية:

```text
UI
  -> Riverpod providers
  -> repositories
  -> SQLite transactions and ledger services
  -> sync_outbox القديم
  -> SyncEngine القديم المبني على row changes
```

طبقة الشبكة أصبحت جاهزة للعنوان الجديد، لكن لا يجوز تفعيل sync الحالي على السيرفر الجديد قبل تنفيذ ترحيل الأحداث الموضح أدناه.

## 4. تعارضات المصادقة

### الموجود حالياً

`AuthNotifier` مجرد حالة محلية:

- لا يأخذ email/password.
- لا يستدعي `/auth/login`.
- لا يخزن access/refresh token.
- لا ينفذ refresh rotation.
- لا يستدعي `/me`.
- لا يدعم memberships أو اختيار المؤسسة.
- logout لا يستدعي السيرفر.

### المطلوب

1. إضافة `flutter_secure_storage`.
2. إنشاء `TokenStorage` يحفظ ذرياً:
   - access token.
   - refresh token.
   - expiresAt.
   - deviceKey الثابت.
   - آخر entity مختارة، أو مفتاح آمن يشير إليها.
3. إنشاء `AuthRemoteDataSource` للمسارات:
   - `POST /auth/login`.
   - `POST /auth/refresh`.
   - `POST /auth/logout`.
   - `GET /me`.
4. ربط callbacks الخاصة بـ`ApiClient` مع `TokenStorage` وrefresh single-flight.
5. عند فشل refresh:
   - مسح التوكنات.
   - إبقاء SQLite وفق سياسة الجهاز.
   - إعادة المستخدم إلى login.
6. إضافة حقول البريد وكلمة المرور إلى شاشة الدخول الحالية.
7. إذا كان للمستخدم أكثر من membership يجب إظهار شاشة اختيار مؤسسة، لا اختيار أول واحدة بصمت.

## 5. تعارض الهوية وLocalContext

### الموجود حالياً

`LocalContextService` ينشئ محلياً عند أول تشغيل:

- entity.
- user.
- device.
- financial year.
- default warehouse.
- default cashbox.

هذه UUID محلية وليست IDs الصادرة من Spring.

### العقد الجديد

- `userId` يأتي من login/JWT.
- `entityId` يأتي من membership في `/me`.
- `deviceId` يصدر من `/entities/{entityId}/devices/register`.
- `deviceKey` فقط يولده Flutter مرة ويحفظه في Secure Storage.

### قرار الترحيل المطلوب

- عدم استبدال IDs المحلية الموجودة بصمت؛ ذلك قد يكسر جميع Foreign Keys.
- للمستخدم الجديد: إنشاء workspace محلي من bootstrap باستخدام IDs الخادم.
- للتثبيت القديم الذي يحتوي بيانات:
  - إما ربط workspace المحلي بمؤسسة خادم فارغة عبر migration/import مراقب.
  - أو إبقاؤه workspace محلياً منفصلاً حتى يوفر الباك عملية import.
- فصل `app_context` والـcursor والـoutbox حسب `entityId` بدلاً من singleton عالمي غير متعدد المؤسسات.

## 6. التعارض الأهم: Draft Events

### عقد السيرفر

- الـDraft محلي فقط.
- لا يوجد `DraftCreated` أو `DraftUpdated` في Event Catalog.
- الحدث يُنشأ فقط عند الترحيل/الاعتماد.
- حدث Post يجب أن يحمل snapshot كاملاً يكفي جهازاً لم ير المسودة.

### الموجود حالياً

`DocumentRepository` يضيف إلى outbox:

```text
sale + action=draft
purchase + action=draft
```

هذا غير مسموح ويؤدي إلى `REJECTED / EVENT_TYPE_NOT_ALLOWED`.

### التغيير المطلوب

- حذف enqueue من `createSaleDraft` و`createPurchaseDraft`.
- تبقى المسودات في جداول SQLite الحالية فقط.
- عند `postSale` إنشاء `SalePosted` واحد كامل.
- عند `postPurchase` إنشاء `PurchasePosted` واحد كامل.
- لا يمكن إعادة استخدام payload القديم كما هو؛ العقد الجديد camelCase ويحتاج IDs للـledger/movements داخل الحدث.
- eventId يولد مرة عند الترحيل ويحفظ في outbox؛ retry يعيد نفس eventId.

## 7. تعارض Outbox المحلي

### `sync_outbox` الحالي

يخزن:

```text
operation_id
aggregate_type
aggregate_id
action
payload_json
attempt_count
status
```

### Event Envelope المطلوب

```text
eventId
aggregateType
aggregateId
eventType
aggregateVersion
occurredAt
payload
```

### Migration مقترح: SQLite v7

إضافة أو إنشاء outbox جديد يتضمن:

```text
event_id TEXT PRIMARY KEY
entity_id TEXT NOT NULL
device_id TEXT NOT NULL
aggregate_type TEXT NOT NULL
aggregate_id TEXT NOT NULL
event_type TEXT NOT NULL
aggregate_version INTEGER NOT NULL
occurred_at TEXT NOT NULL
payload_json TEXT NOT NULL
status TEXT NOT NULL
attempt_count INTEGER NOT NULL DEFAULT 0
last_error_code TEXT
last_error_message TEXT
next_retry_at TEXT
created_at TEXT NOT NULL
```

الفهارس المطلوبة:

```text
(entity_id, status, next_retry_at)
(entity_id, aggregate_type, aggregate_id, aggregate_version)
```

يجب إنشاء الحدث وحركة الـledger وتحديث المستند داخل SQLite transaction واحدة.

## 8. تعارض Push

### الموجود حالياً

- `SyncTransport.push` يرسل عملية واحدة.
- النتيجة Boolean فقط: accepted/error.
- `SyncEngine` يعيد كل الأخطاء باستخدام backoff تقريباً.

### العقد الجديد

- `POST /sync/push` يرسل envelope يحتوي حتى 100 Event.
- HTTP 200 يحتوي نتيجة مستقلة لكل event:
  - `ACCEPTED`.
  - `ALREADY_ACCEPTED`.
  - `CONFLICT`.
  - `REJECTED`.
- network و5xx فقط يعادان تلقائياً.
- 4xx و`REJECTED` terminal حتى إصلاح السبب.
- `CONFLICT` ينقل الحدث إلى `sync_conflicts`.

### المطلوب

- استبدال `SyncPushResult` بنتائج batch المطابقة للعقد.
- تجميع بحد أقصى 100 حدث للمؤسسة والجهاز نفسيهما.
- عند `ACCEPTED` أو `ALREADY_ACCEPTED`: حذف/تعليم outbox كمنتهٍ.
- عند `CONFLICT`: إنشاء conflict وعدم retry.
- عند `REJECTED`: حفظ code/message وإيقاف retry.
- منع أكثر من sync loop للمؤسسة نفسها بواسطة mutex.

## 9. تعارض Pull: تغييرات صفوف مقابل Domain Events

### الموجود حالياً

المحرك يتوقع:

```text
table_name
record_id
change_type
record_version
payload_json
```

ثم يقوم بعمل insert/update مباشر حسب اسم الجدول.

### العقد الجديد

السيرفر يعيد:

```text
serverSequence
eventId
aggregateType
aggregateId
eventType
aggregateVersion
payload
```

### النتيجة

دالة `_applyChange` الحالية لا يمكن تعديلها بشكل بسيط؛ يجب استبدالها بـEvent Projectors صريحة وحتمية، مثل:

- `PartyCreatedProjector`.
- `ProductUpdatedProjector`.
- `SalePostedProjector`.
- `InventoryTransferredProjector`.
- `ExpenseVoidedProjector`.

لا يسمح باستخدام اسم جدول قادم من الشبكة كاسم SQL ديناميكي.

## 10. تعارض `sync_changes` وdeduplication

### الموجود حالياً

`sync_changes` يخزن sequence وتغيير الصف، ولا يملك عمود `event_id` فريداً.

### المطلوب

في SQLite v7:

- إضافة `event_id TEXT NOT NULL UNIQUE`.
- تخزين `event_type`, `aggregate_type`, `aggregate_id`, `aggregate_version`.
- داخل transaction تطبيق الحدث:
  1. إذا eventId موجود، لا تعِد projection.
  2. مع ذلك تقدم cursor بعد نجاح الدفعة.
  3. إذا النوع أو payload version غير مدعوم، توقف الدفعة ولا تقدم cursor.

## 11. Bootstrap وAck وStatus

غير موجودة في المحرك الحالي ويجب إضافتها:

- `GET /sync/bootstrap` لأول مؤسسة/إعادة بناء فقط.
- `GET /sync/pull` ضمن loop حتى `hasMore=false`.
- حفظ projections وeventIds وcursor داخل SQLite transaction.
- `POST /sync/ack` بعد commit فقط.
- `GET /sync/status` لواجهة الحالة.
- منع sync إذا الجهاز `revoked`.

Bootstrap v1 الحالي يحتوي cashboxes فقط. لذلك لا يجوز حذف business SQLite القديمة ثم توقع استرجاع كل المنتجات والفواتير من bootstrap الحالي. هذه نقطة يجب الاتفاق عليها مع الباك قبل دعم rebuild كامل.

## 12. تعارض `cash_sessions`

### الموجود حالياً

المشروع يحتوي:

- جدول `cash_sessions`.
- فتح وإغلاق جلسة.
- outbox actions باسم `cash_session/open/close`.
- واجهة مستقلة للجلسات.

### العقد الجديد

- وثيقة السيرفر تنص صراحة أنه لا توجد Cash Sessions.
- لا يوجد `cash_session` في Event Catalog أو مصفوفة الأنواع.

### القرار المقترح

الإبقاء على `cash_sessions` ميزة محلية فقط مؤقتاً:

- إزالة open/close من outbox.
- عدم إرسالها إلى `/sync/push`.
- توضيح في UI أنها غير متزامنة عند العمل متعدد الأجهزة.

إذا كانت جلسات الصندوق مطلوبة كميزة مشتركة، يجب أن يضيف الباك عقداً رسمياً مثل:

```text
CashSessionOpened
CashSessionClosed
CashSessionAdjusted
```

مع concurrency policy قبل تفعيل مزامنتها.

## 13. تعارضات Event Catalog مع وظائف المشروع

تحتاج حسم مع مطور الباك قبل إكمال projectors:

| ميزة Flutter | وضع العقد الحالي |
|---|---|
| `financial_year` create/close | غير موجود في Event Catalog |
| `product_specification` | غير موجود في Event Catalog |
| `WarehouseDeleted` | لا يوجد، بينما التطبيق يسمح بالأرشفة |
| تحديث cashbox | لا يوجد `CashboxUpdated` |
| سعر الوحدة `sale_price_minor` | غير موجود في `ProductUnitCreated/Updated` payload |
| cash adjustment | التطبيق يستخدم aggregate `cash_adjustment`؛ الكتالوج يضع الحدث تحت `cashbox` |
| opening balance | التطبيق يستخدم `cash_opening_balance`؛ العقد يستخدم `CashOpeningBalanceSet` تحت `cashbox` |
| إلغاء المرتجعات والهالك | التطبيق يدعم void أوسع من الأنواع المذكورة في الكتالوج |
| party fields | العقد يحتوي email/address/taxNumber/creditLimit، وSQLite الحالية لا تحتويها |
| party type | SQLite lowercase، والحدث uppercase |
| Cash Sessions | غير مدعومة على السيرفر |

حتى يتم حسمها، يجب ألا يحوّل Flutter هذه العمليات إلى eventTypes غير موثقة.

## 14. ترتيب التنفيذ المقترح

### المرحلة A — الاتصال والمصادقة

- [x] `ApiConfig` والدومين الجديد.
- [x] Dio موحد وآمن.
- [x] منع تكرار `/api/v1` و`/admin`.
- [x] صلاحية Android Release.
- [ ] Secure token storage.
- [ ] login/refresh/logout/me.
- [ ] شاشة اختيار المؤسسة.
- [ ] تسجيل الجهاز.

### المرحلة B — SQLite v7

- [ ] Event outbox schema.
- [ ] eventId dedup schema.
- [ ] per-entity cursor/workspace.
- [ ] منع draft events.
- [ ] جعل cash sessions محلية فقط.

### المرحلة C — Event Builders

- [ ] Master-data events.
- [ ] inventory events.
- [ ] sale/purchase/return/waste snapshots.
- [ ] cash/party ledger events.
- [ ] aggregateVersion policy.

### المرحلة D — Sync HTTP

- [ ] bootstrap.
- [ ] batch push.
- [ ] event pull/projectors.
- [ ] ack/status.
- [ ] retry classification وmutex.

### المرحلة E — التحقق

- [ ] login + refresh rotation integration tests.
- [ ] نفس eventId عند timeout/retry.
- [ ] event صادر من الجهاز نفسه لا يطبق مرتين.
- [ ] conflict لا يعاد تلقائياً.
- [ ] cursor لا يتقدم عند فشل projector.
- [ ] عزل مؤسستين على الجهاز نفسه.
- [ ] revoked device يوقف sync.
- [ ] عدم إرسال أي draft أو cash session.

## 15. أوامر التشغيل

القيمة الإنتاجية موجودة افتراضياً، ويمكن تمريرها صراحة:

```bash
flutter run --dart-define=API_BASE_URL=https://accounting.alkhaleel-mosque.com/api/v1
```

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://accounting.alkhaleel-mosque.com/api/v1
```

لا تضع secrets أو credentials داخل `--dart-define` أو Git؛ هذا المتغير لعنوان عام فقط.
