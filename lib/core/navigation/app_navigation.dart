import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/features/cash/ui/cash_screen.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'app_route.dart';
import 'desktop_navigation_controller.dart';
import 'route_builder.dart';

class AppNavigation {
  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);
  static void open(AppRoute route) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context != null && _openCreationDialog(context, route.type)) return;
    if (_desktop) {
      globalContainer.read(appNavigatorProvider).open(route);
    } else {
      if (context != null)
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => buildPage(route)));
    }
  }

  static bool _openCreationDialog(BuildContext context, RouteType type) {
    switch (type) {
      case RouteType.newSale:
        showNewDocumentDialog(
          context,
          kind: DocumentKind.sale,
          onExpenseRequested: showExpenseDocumentDialog,
        );
        return true;
      case RouteType.purchases:
        showNewDocumentDialog(
          context,
          kind: DocumentKind.purchase,
          onExpenseRequested: showExpenseDocumentDialog,
        );
        return true;
      case RouteType.waste:
        showNewDocumentDialog(
          context,
          kind: DocumentKind.waste,
          onExpenseRequested: showExpenseDocumentDialog,
        );
        return true;
      case RouteType.expenses:
        showExpenseDocumentDialog(context);
        return true;
      default:
        return false;
    }
  }

  static void openReplacement(AppRoute route) {
    if (_desktop) {
      globalContainer.read(desktopNavControllerProvider).replaceRoot(route);
    } else {
      final c = AccountingSystem.navigatorKey.currentContext;
      if (c != null)
        Navigator.of(
          c,
        ).pushReplacement(MaterialPageRoute(builder: (_) => buildPage(route)));
    }
  }

  static void back() {
    if (_desktop) {
      globalContainer.read(desktopNavControllerProvider).pop();
    } else {
      AccountingSystem.navigatorKey.currentState?.maybePop();
    }
  }
}
