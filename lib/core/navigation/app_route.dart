class AppRoute<T> {
  final RouteType type;
  final T? args;

  const AppRoute({required this.type, this.args});

  String get title => type.title;
}

enum RouteType {
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
}

extension RouteTypeExtension on RouteType {
  String get title => switch (this) {
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
    RouteType.settings => 'الإعدادات',
  };
}
