# التسليم النهائي لتوافق Backend مع تطبيق Flutter المحاسبي

**الإصدار:** 2026-10-01  
**عنوان Flutter الإنتاجي:** `https://accounting.alkhaleel-mosque.com/api/v1`  
**قاعدة التوافق:** لا يرسل Flutter حدثاً أو حقلاً غير معتمد صراحةً في Event Catalog/OpenAPI.

---

## 1. مانع الإصدار الحالي — السنة المالية (P0)

### الخطأ الحالي

يرفض الباك فواتير Flutter بالرسالة:

```text
Financial year must be synchronized before the document
```

السبب: التطبيق ينشئ السنة المالية محلياً، بينما العقد المنشور لا يوفّر طريقة
لإنشائها أو استعادتها من الباك قبل إرسال المستندات. لذلك لا يتعرف الباك على
`financialYearId` الموجود في `SalePosted` و`PurchasePosted` وغيرها.

### المطلوب (الخيار المفضل)

إضافة الأحداث التالية إلى Event Catalog، وقبولها في `POST /sync/push` وإعادتها
في `GET /sync/pull` وضمن bootstrap الكامل عند الحاجة:

```text
FinancialYearCreated
FinancialYearUpdated
FinancialYearActivated
FinancialYearClosed
```

#### FinancialYearCreated payload

```json
{
  "financialYearId": "uuid",
  "name": "2026",
  "startsOn": "2026-01-01",
  "endsOn": "2026-12-31",
  "status": "open",
  "createdAt": "2026-10-01T10:00:00Z"
}
```

القواعد المطلوبة:

- المعرف UUID ثابت ويعيد الباك نفس المعرف في pull/replay.
- السنة تتبع `entityId` من envelope؛ لا يوضع entity من مؤسسة أخرى في payload.
- لا يسمح بتداخل سنتين مفتوحتين إن كانت هذه سياسة الباك.
- `FinancialYearActivated` يحدد سنة نشطة واحدة لكل مؤسسة.
- لا يقبل الباك مستنداً قبل وجود السنة المالية على السيرفر.
- يجب ترتيب السنة المالية قبل أي حدث يعتمد عليها (`WarehouseCreated`،
  `SalePosted`، `PurchasePosted`، الحركات، الدفعات).

### بديل مقبول إن لم تُضاف الأحداث

ينشئ الباك السنة المالية عند إنشاء المؤسسة، ويعيدها دائماً في:

```text
GET /me أو GET /sync/bootstrap
```

مع `id`, `name`, `startsOn`, `endsOn`, `status`, و`isActive`.

هذا البديل لا يكفي إذا كان Flutter يستطيع إنشاء سنوات متعددة محلياً؛ عندها
تبقى الأحداث المذكورة أعلاه مطلوبة.

---

## 2. ضمان جهاز جديد وSync v1.1 (P0)

`bootstrap` الحالي قد يحتوي snapshot جزئياً للصناديق فقط. لا يجوز أن يجعل ذلك
Flutter يتجاوز المنتجات أو الأطراف أو المستندات السابقة.

### GET /sync/bootstrap

يلزم الرد بهذه الحقول، مع احترام معناها:

```json
{
  "snapshotCompleteness": "PARTIAL",
  "replayFromSequence": 0,
  "earliestAvailableSequence": 1,
  "fullReplayAvailable": true,
  "serverSequence": 150,
  "snapshot": { "cashboxes": [] }
}
```

- `snapshotCompleteness=PARTIAL`: الصناديق مساعدة فقط وليست قاعدة بيانات كاملة.
- يبدأ Flutter pull من `replayFromSequence`، **وليس** من `serverSequence`.
- `serverSequence` watermark عالمي؛ يجوز وجود فجوات، ولا يفترض Flutter أرقاماً
  متجاورة.
- `earliestAvailableSequence` يمكن أن يكون `null` فقط عندما لا توجد أحداث.
- إذا كان التاريخ المطلوب لم يعد متاحاً: رد منظم `409 CURSOR_TOO_OLD` مع
  `earliestAvailableSequence`، ولا ترد بنجاح ناقص.
- لا يرسل Flutter ack ولا يثبت bootstrap مكتملًا قبل الوصول إلى watermark.

### GET /sync/pull

- ترتيب تصاعدي حسب `serverSequence`.
- نفس `eventId` يعاد بأمان؛ العميل يطبق الحدث مرة واحدة فقط.
- يجب أن يستطيع جهاز جديد استعادة جميع أحداث المؤسسة من
  `replayFromSequence` حتى watermark.
- لا تعتمد صحة pull على أن snapshot يحتوي كل البيانات.

### POST /sync/push

لكل حدث نتيجة مستقلة ضمن HTTP 200:

```text
ACCEPTED | ALREADY_ACCEPTED | CONFLICT | REJECTED
```

- timeout أو إعادة المحاولة لنفس العملية يجب أن يعيد `ALREADY_ACCEPTED` لنفس
  `eventId`، لا أن ينشئ عملية ثانية.
- لا يعيد Flutter تلقائياً `REJECTED` أو `CONFLICT` بلا تصحيح واضح.

---

## 3. ترتيب الاعتماديات (P0)

يجب على الباك قبول/إرجاع الأحداث وفق الاعتماديات التالية:

```text
FinancialYearCreated
  → CategoryCreated / WarehouseCreated / CashboxCreated / PartyCreated
  → ProductCreated
  → ProductUnitCreated
  → BarcodeCreated
  → InventoryOpeningPosted / PurchasePosted
  → SalePosted / Returns / Payments / Expenses
```

لا يجوز أن يصل `InventoryOpeningPosted` قبل `WarehouseCreated` الخاص بنفس
`warehouseId`. إذا لم يستطع الباك ضمان هذا الترتيب، يجب أن يعيد خطأ اعتماد
منظم قابل للقراءة، لا 500 أو نجاحاً جزئياً مضللاً.

---

## 4. المنتجات والوحدات والباركود (P0)

### سعر بيع الوحدة

يجب أن يحتوي **كل من** الحدثين التاليين على الحقل:

```text
ProductUnitCreated
ProductUnitUpdated
```

```json
{
  "id": "uuid",
  "productId": "uuid",
  "name": "قطعة",
  "factor": 1,
  "primary": true,
  "salePriceMinor": 10000,
  "updatedAt": "2026-10-01T10:00:00Z"
}
```

القواعد:

- `salePriceMinor` عدد صحيح غير سالب بوحدة العملة الصغرى، وليس `double` أو نصاً.
- الحدث التاريخي الذي لا يحمله يقبل محلياً بسعر صفر فقط؛ لا يعدل Flutter الحدث
  التاريخي ولا يعيد إرساله.
- يجب السماح بعدة وحدات للمنتج مع `factor` موجب، ووحدة رئيسية واحدة فقط لكل
  منتج.
- منع تكرار الباركود على مستوى المؤسسة، وإرجاع `409`/نتيجة REJECTED مفهومة.

---

## 5. الفواتير والربحية والمخزون (P0)

ينتج Flutter أحداث المستندات المرحّلة فقط. المسودة لا ترسل.

يلزم لكل بند في أحداث البيع/الشراء/المرتجعات/الهالك:

```json
{
  "itemId": "uuid",
  "itemType": "product",
  "productId": "uuid",
  "productUnitId": "uuid",
  "warehouseId": "uuid",
  "baseQuantity": 1,
  "unitFactor": 1,
  "netAmountMinor": 10000,
  "costAmountMinor": 1000,
  "inventoryMovementId": "uuid"
}
```

- جميع حقول `*Minor` أعداد صحيحة.
- `baseQuantity` هي الكمية بعد التحويل للوحدة الأساسية؛ لا تجمع وحدات مختلفة
  قبل التحويل.
- `costAmountMinor` تكلفة فعلية مثبتة للحركة، وتستخدم في الربحية؛ لا يستبدلها
  الباك بسعر البيع.
- يوزع خصم الفاتورة نسبيًا على البنود، ويحفظ فرق التقريب في آخر بند.
- الإلغاء والمرتجع يعكسان النقد والمخزون والطرف والتكلفة مرة واحدة فقط.
- يجب أن تكون معرفات حركات المخزون والأطراف والصندوق كافية لإعادة البناء على
  جهاز ثانٍ.

---

## 6. العملات وأسعار الصرف (P1)

عملة المؤسسة الأساسية المطلوبة حالياً: `SYP`، ورمز العرض في Flutter: `ل.س`.
يلزم أن يعيد `GET /me`:

```json
{ "currencyCode": "SYP", "timezone": "Asia/Damascus" }
```

### أحداث مطلوبة للمزامنة

```text
CurrencyCreated
CurrencyUpdated
CurrencyArchived
ExchangeRateRecorded
```

```json
{
  "rateId": "uuid",
  "currencyCode": "USD",
  "rateMicros": 1400000000,
  "effectiveAt": "2026-10-01T00:00:00Z",
  "createdAt": "2026-10-01T10:00:00Z"
}
```

`rateMicros` = قيمة وحدة رئيسية واحدة من العملة الأجنبية بعملة المؤسسة الأساسية
× `1,000,000`. مثال: 1 USD = 1400 ل.س ⇒ `1400000000`.

لأحداث المستندات متعددة العملات نحتاج أيضاً:

```json
{
  "currencyCode": "USD",
  "exchangeRateMicros": 1400000000,
  "foreignSubtotalMinor": 7,
  "foreignDiscountMinor": 0,
  "foreignFinalMinor": 7,
  "foreignPaidMinor": 7
}
```

يبقى المبلغ المحاسبي الرسمي في حقول العملة الأساسية `*Minor` الحالية.

---

## 7. تخصيص الدفعات والاستحقاقات (P1)

رصيد الطرف وحده لا يثبت المتبقي الدقيق لكل فاتورة. نحتاج:

```text
payment_allocations
PaymentAllocationCreated
PaymentAllocationReversed
```

```json
{
  "id": "uuid",
  "paymentId": "uuid",
  "documentId": "uuid",
  "documentType": "sale | purchase | sale_return | purchase_return",
  "allocatedMinor": 50000,
  "allocatedAt": "2026-10-01T10:00:00Z",
  "reversalOfId": null
}
```

وأضف `dueDate` اختياريًا للمستندات الآجلة. بدونه لا يمكن إصدار تقرير تقادم
ديون صحيح.

---

## 8. رأس المال والشركاء ودفتر الأستاذ (P1)

Flutter يدعم هذه البيانات محلياً الآن، لكنها **غير متزامنة حالياً** لعدم وجود
عقد معتمد. إذا أريد استخدامها بين أجهزة متعددة، نحتاج الأحداث:

```text
CapitalPartnerCreated / CapitalPartnerUpdated
CapitalContributionRecorded
CapitalCashAllocated
GlAccountCreated / GlAccountUpdated
JournalEntryPosted / JournalEntryReversed
```

الضمانات:

- كل قيد يحتوي طرفين أو أكثر ومجموع المدين = مجموع الدائن.
- المصدر (`sourceType`, `sourceId`) فريد، فلا ينشأ قيدان عند retry أو replay.
- الإلغاء ينشئ قيداً عكسياً ولا يغير القيد المرحّل.
- لا يرسل Flutter هذه الأحداث قبل اعتمادها في الكتالوج.

---

## 9. نقاط API إضافية

- Flutter يستخدم HTTPS فقط، ولا يستخدم `/admin/`.
- `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /me`.
- `GET /me` يعيد memberships والمؤسسات وصلاحية المستخدم و`currencyCode` و
  `timezone` والسنة المالية النشطة أو قائمة السنوات.
- إن كان endpoint أعضاء المؤسسة معتمداً، يجب أن يكون
  `GET /entities/{entityId}/members` موجوداً فعلاً؛ كان يعيد 404 سابقاً.
- 401 يؤدي إلى refresh واحد فقط من Flutter؛ 403 أو `revoked=true` يوقف مزامنة
  الجهاز ويعرض الحالة للمستخدم.

---

## 10. اختبار قبول مشترك قبل النشر

1. مؤسسة اختبار جديدة وسنة مالية منشأة على الباك ومزامنة إلى جهاز A وB.
2. جهاز A ينشئ مستودعاً، صندوقاً، تصنيفاً، منتجاً ووحدة بسعر بيع غير صفري.
3. يسجل رصيد مخزون، ثم بيعاً نقدياً/آجلاً ودفعة ومرتجعاً أو إلغاءً.
4. يسجل USD بسعر 1400، وينشئ فاتورة USD؛ يتحقق من المبلغ الأصلي والمقابل SYP.
5. جهاز B يسحب ويطابق المعرفات والأسعار والأرصدة وسجل الطرف.
6. اختبار retry لنفس `eventId` بعد انقطاع الشبكة؛ النتيجة `ALREADY_ACCEPTED`.
7. اختبار جهاز جديد يبدأ من `replayFromSequence` ويستعيد التاريخ كاملاً.

## قرار مطلوب من الباك

لا يمكن اعتبار مزامنة الفواتير مكتملة قبل تنفيذ **القسم 1** على الأقل.  
يجب تزويد Flutter بإصدار Event Catalog/OpenAPI محدّث بعد الاعتماد، حتى يطبّق
التطبيق الحقول والأحداث حرفياً دون افتراضات.
