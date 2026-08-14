class AppRoute<T> {
  final RouteType type;
  final T? args;
  const AppRoute({required this.type, this.args});
  String get title => type.title;
}

enum RouteType {
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
}

extension RouteTypeExtension on RouteType {
  String get title => switch (this) {
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
    RouteType.settings => 'الإعدادات',
  };
}
