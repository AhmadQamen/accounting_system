# متطلبات تهيئة جهاز جديد — Sync v1

> تحديث 2026-09-25: اعتمد الباك الخيار A في Sync Contract v1.1 وأضاف
> `snapshotCompleteness` و`replayFromSequence` و`earliestAvailableSequence`
> و`fullReplayAvailable`. تم تنفيذ قراءتها والتحقق منها في Flutter.

## المشكلة المثبتة

`GET /sync/bootstrap` في العقد الحالي يعيد snapshot للصناديق فقط، مع
`serverSequence`. استخدام هذا الرقم مباشرة كـcursor يجعل الجهاز يتجاوز أحداث
المنتجات والأطراف والمستودعات والمستندات السابقة.

## سلوك Flutter المنفذ الآن

1. يدمج cashboxes من bootstrap ولا يعتبرها قاعدة أعمال كاملة.
2. يعامل `serverSequence` كـ **هدف اكتمال** فقط.
3. يبدأ `GET /sync/pull` من `after=0` للجهاز الجديد أو rebuild.
4. يواصل pull حتى `hasMore=false`.
5. لا يثبت `bootstrap_completed`، ولا يرسل ack، ولا يسجل آخر مزامنة ناجحة إذا
   كان آخر sequence المستلم أقل من هدف bootstrap.
6. ترقية SQLite v10 تعيد cursor إلى صفر مرة واحدة للأجهزة التي ربما تخطت
   التاريخ بسبب السلوك القديم، مع deduplication بواسطة `eventId`.
7. snapshot الجزئي لا يستبدل رصيد صندوق لديه ledger محلي؛ الرصيد يبنى من
   الحركات.

هذا الحل صحيح فقط إذا كان الباك يستطيع إعادة **كل** أحداث المؤسسة منذ
`serverSequence=1` عبر `/sync/pull?after=0`.

## الضمان المطلوب من فريق الباك

يجب اعتماد أحد الخيارين التاليين صراحةً:

### الخيار A — Event replay كامل

- ضمان الاحتفاظ بكل `domain_events` للمؤسسة وعدم حذف التاريخ المطلوب لبناء جهاز جديد.
- `pull(after=0)` يعيد كل الأحداث بترتيب متصل تصاعديًا حتى watermark الخاص بـbootstrap.
- إضافة `earliestAvailableSequence` إلى bootstrap/status.
- إذا طلب العميل cursor أقدم من المتاح، يعيد الباك خطأً منظمًا، مثل:
  `409 CURSOR_TOO_OLD` مع `earliestAvailableSequence`، بدل نجاح ناقص.
- يفضّل إضافة الحقول التالية إلى bootstrap:

```json
{
  "serverSequence": 15000,
  "snapshotCompleteness": "PARTIAL",
  "replayFromSequence": 0,
  "earliestAvailableSequence": 1,
  "snapshotVersion": 1,
  "snapshot": {"cashboxes": []}
}
```

### الخيار B — Snapshot كامل

إذا كان الاحتفاظ بكل الأحداث غير مضمون، يجب أن يعيد bootstrap snapshot ذريًا
وكاملًا عند `serverSequence` نفسه، ويشمل على الأقل:

- السنوات المالية.
- الأطراف والتصنيفات والمنتجات والوحدات والباركود.
- المستودعات والصناديق.
- المستندات وبنودها وحالات الإلغاء.
- inventory/cash/party ledgers أو projections كاملة مع معلومات تحقق للأرصدة.
- aggregate versions اللازمة لأول push بعد الاستعادة.

بعد تطبيق snapshot الكامل فقط يبدأ pull من `serverSequence`.

## الاعتماديات والمعرفات

- عقد v1 لا يعرّف Event للسنة المالية ولا يضعها في bootstrap. Flutter يستخدم
  fallback UUID v5 حتميًا مشتقًا من `entityId` والسنة، ويستخدم UUIDs حتمية
  للمستودع والصندوق الافتراضيين كي تتطابق على الأجهزة الجديدة.
- هذا لا يصلح تلقائيًا بيانات أجهزة قديمة أنشأت UUIDs عشوائية. لهذه البيانات
  يجب أن يضمن الباك وصول `WarehouseCreated` و`CashboxCreated` قبل المستندات،
  وأن يضيف `FinancialYearCreated` إلى الكتالوج أو يضع السنوات المالية في
  bootstrap الكامل.
- الحل المفضل طويل الأجل: الباك هو مصدر معرفات الاعتماديات الافتراضية ويعيدها
  ضمن bootstrap/entity configuration، ولا ينشئ كل جهاز معرفات أعمال مستقلة.

## legacy_sync_quarantine

- لا يرسل Flutter أي صف معزول ولا يحوله إلى Event بالتخمين.
- SQLite v10 تضيف حالات مراجعة: `pending_review` و`kept_local` و`discarded`،
  مع وقت وملحوظة القرار.
- تبقى البيانات الأصلية محفوظة ويظهر عدد `pending_review` في حالة المزامنة.
- النقل إلى السيرفر يحتاج أداة import منفصلة من فريق الباك بعقد صريح، أو مراجعة
  يدوية تختار eventType وpayload وaggregateVersion لكل عملية. لا يعاد إدخالها
  إلى outbox العام آليًا.
