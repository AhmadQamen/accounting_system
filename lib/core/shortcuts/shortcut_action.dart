enum ShortcutAction {
  newSale,
  newReturn,
  newPurchase,
  newWaste,
  sync,
  viewSales,
  viewReturns,
  viewMovements,
  viewInventory,
  viewSuppliers,
  settings,
<<<<<<< HEAD
  medicineRef,
=======
  reports,
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
}

extension ShortcutActionLabel on ShortcutAction {
  String get label {
    switch (this) {
      case ShortcutAction.newSale:
        return 'فاتورة بيع';
      case ShortcutAction.newReturn:
        return 'فاتورة مرتجع';
      case ShortcutAction.newPurchase:
        return 'فاتورة شراء';
      case ShortcutAction.newWaste:
        return 'فاتورة تلف';
      case ShortcutAction.sync:
        return 'مزامنة';
      case ShortcutAction.viewSales:
        return 'عرض المبيعات';
      case ShortcutAction.viewReturns:
        return 'عرض المرتجعات';
      case ShortcutAction.viewMovements:
        return 'حركة المواد';
      case ShortcutAction.viewInventory:
        return 'المخزون';
      case ShortcutAction.viewSuppliers:
        return 'الموردين';
      case ShortcutAction.settings:
        return 'الإعدادات';
<<<<<<< HEAD
      case ShortcutAction.medicineRef:
        return 'مرجع الأدوية';
=======
      case ShortcutAction.reports:
        return 'التقارير';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
    }
  }

  String get description {
    switch (this) {
      case ShortcutAction.newSale:
        return 'فتح واجهة إنشاء فاتورة بيع جديدة';
      case ShortcutAction.newReturn:
        return 'فتح واجهة إنشاء فاتورة مرتجع';
      case ShortcutAction.newPurchase:
        return 'فتح واجهة إنشاء فاتورة شراء';
      case ShortcutAction.newWaste:
        return 'فتح واجهة إنشاء فاتورة تلف';
      case ShortcutAction.sync:
        return 'مزامنة البيانات مع الخادم';
      case ShortcutAction.viewSales:
        return 'عرض قائمة فواتير المبيعات';
      case ShortcutAction.viewReturns:
        return 'عرض قائمة المرتجعات';
      case ShortcutAction.viewMovements:
        return 'عرض حركة المواد في المخزون';
      case ShortcutAction.viewInventory:
        return 'عرض المخزون الحالي';
      case ShortcutAction.viewSuppliers:
        return 'عرض قائمة الموردين';
      case ShortcutAction.settings:
        return 'فتح صفحة الإعدادات';
<<<<<<< HEAD
      case ShortcutAction.medicineRef:
        return 'فتح نافذة البحث عن الأدوية';
=======
      case ShortcutAction.reports:
        return 'فتح صفحة التقارير';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
    }
  }
}
