class AppRoute<T> {
  final RouteType type;
  final T? args;
<<<<<<< HEAD

  const AppRoute({required this.type, this.args});

=======
  const AppRoute({required this.type, this.args});
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
  String get title => type.title;
}

enum RouteType {
<<<<<<< HEAD
  accounting,
  inventory,
  saleDashboard,
  store,
  saleDetails,
  customerDetails,
  settings,
  medicines,
  notifications,
  newInvoice,
  customers,
  suppliers,
=======
  dashboard,
  newSale,
  sales,
  purchases,
  saleReturns,
  purchaseReturns,
  inventory,
  products,
  warehouses,
  inventoryAdjustments,
  inventoryTransfers,
  waste,
  parties,
  customers,
  suppliers,
  cashboxes,
  expenses,
  cashTransfers,
  cashSessions,
  financialYears,
  reports,
  settings,
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
}

extension RouteTypeExtension on RouteType {
  String get title => switch (this) {
<<<<<<< HEAD
    RouteType.accounting => 'المحاسبة',
    RouteType.store => 'المتجر',
    RouteType.medicines => 'الأدوية',
    RouteType.saleDashboard => 'سجل المبيعات',
    RouteType.newInvoice => 'فاتورة جديدة',
    RouteType.inventory => 'المخزون',
    RouteType.suppliers => 'الموردين',
    RouteType.customers => 'الزبائن',
    RouteType.saleDetails => 'تفاصيل الفاتورة',
    RouteType.customerDetails => 'تفاصيل العميل',
    RouteType.notifications => 'الإشعارات',
=======
    RouteType.dashboard => 'لوحة التحكم',
    RouteType.newSale => 'فاتورة بيع جديدة',
    RouteType.sales => 'المبيعات',
    RouteType.purchases => 'المشتريات',
    RouteType.saleReturns => 'مرتجعات البيع',
    RouteType.purchaseReturns => 'مرتجعات الشراء',
    RouteType.inventory => 'المخزون',
    RouteType.products => 'المنتجات',
    RouteType.warehouses => 'المستودعات',
    RouteType.inventoryAdjustments => 'الجرد والتسويات',
    RouteType.inventoryTransfers => 'تحويلات المستودعات',
    RouteType.waste => 'الهالك',
    RouteType.parties => 'الأطراف',
    RouteType.customers => 'العملاء',
    RouteType.suppliers => 'الموردون',
    RouteType.cashboxes => 'الصناديق',
    RouteType.expenses => 'المصروفات',
    RouteType.cashTransfers => 'تحويلات الصندوق',
    RouteType.cashSessions => 'جلسات الصندوق',
    RouteType.financialYears => 'السنوات المالية',
    RouteType.reports => 'التقارير',
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
    RouteType.settings => 'الإعدادات',
  };
}
