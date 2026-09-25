# طلب تعديل عقد سعر بيع وحدة المنتج

## الحالة الحالية

`EVENT_CATALOG_AR.md` يعرّف `ProductUnitCreated` و`ProductUnitUpdated` بالحقول:

```json
{
  "id": "uuid",
  "productId": "uuid",
  "name": "كرتونة",
  "factor": 12.0,
  "primary": false,
  "updatedAt": "2026-09-24T10:00:00Z"
}
```

لا يوجد حقل لسعر البيع. لذلك لا يستطيع Flutter نقل `sale_price_minor` بصورة
مطابقة للعقد، وكان الجهاز المستقبل ينشئ الوحدة بسعر صفر.

## التعديل المطلوب من فريق الباك

إصدار نسخة محدثة متزامنة من `EVENT_CATALOG_AR.md` وJSON Schema وOpenAPI تضيف
الحقل التالي إلى الحدثين فقط:

```json
"salePriceMinor": 125000
```

الشروط المطلوبة:

- الحقل required في `ProductUnitCreated` و`ProductUnitUpdated`.
- نوعه integer بوحدة العملة الصغرى، وقيمته `>= 0`.
- يحفظ داخل domain event كما أرسله العميل ويعود دون تغيير في `/sync/pull`.
- يرفض الخادم payload المفقود أو غير الصحيح بكود واضح، مثل
  `EVENT_PAYLOAD_INVALID`، بعد رفع نسخة العقد.
- تحديد توافق الأحداث القديمة: عند عدم وجود الحقل في Event قديم، تكون القيمة
  صفرًا فقط لتلك الأحداث التاريخية، مع توثيق version/cutover sequence.

## سلوك Flutter المؤقت

لا يرسل Flutter حقلًا غير معتمد. إلى أن يعتمد الباك التعديل، يمنع التطبيق حفظ
سعر بيع غير صفري لوحدة المنتج ويشرح أن السعر سيُفقد على الجهاز الآخر. هذا يمنع
إظهار مزامنة ناجحة مع بيانات مختلفة.

بعد اعتماد العقد يجب تنفيذ التغييرات معًا:

1. إضافة `salePriceMinor` إلى validator المحلي وpayload في repository.
2. قراءة الحقل في projector بدل تثبيت `sale_price_minor = 0`.
3. اختبار push/pull حقيقي بين جهازين على مؤسسة اختبار.
