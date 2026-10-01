import 'package:accounting_system/core/navigation/app_navigator.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'shortcut_action.dart';

class ShortcutExecutor {
  final AppNavigator _navigator;

  ShortcutExecutor({required AppNavigator navigator}) : _navigator = navigator;

  void execute(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.newSale:
        _navigator.open(const AppRoute(type: RouteType.newSale));
      case ShortcutAction.newReturn:
        _navigator.open(const AppRoute(type: RouteType.saleReturns));
      case ShortcutAction.newPurchase:
        _navigator.open(const AppRoute(type: RouteType.purchases));
      case ShortcutAction.newWaste:
        _navigator.open(const AppRoute(type: RouteType.waste));
      case ShortcutAction.sync:
        _navigator.open(const AppRoute(type: RouteType.sync));
      case ShortcutAction.viewSales:
        _navigator.open(const AppRoute(type: RouteType.sales));
      case ShortcutAction.viewReturns:
        _navigator.open(const AppRoute(type: RouteType.saleReturns));
      case ShortcutAction.viewMovements:
      case ShortcutAction.viewInventory:
        _navigator.open(const AppRoute(type: RouteType.inventory));
      case ShortcutAction.viewSuppliers:
        _navigator.open(const AppRoute(type: RouteType.suppliers));
      case ShortcutAction.settings:
        _navigator.open(const AppRoute(type: RouteType.settings));
      case ShortcutAction.reports:
        _navigator.open(const AppRoute(type: RouteType.reports));
    }
  }
}
