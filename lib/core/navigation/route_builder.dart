import 'package:accounting_system/features/accounting/ui/screens/accounting_home.dart';
import 'package:accounting_system/features/cash/ui/cash_screen.dart';
import 'package:accounting_system/features/documents/ui/document_list_screen.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:accounting_system/features/inventory/ui/inventory_action_screen.dart';
import 'package:accounting_system/features/inventory/ui/inventory_screen.dart';
import 'package:accounting_system/features/master_data/ui/financial_years_screen.dart';
import 'package:accounting_system/features/master_data/ui/parties_screen.dart';
import 'package:accounting_system/features/master_data/ui/products_screen.dart';
import 'package:accounting_system/features/master_data/ui/warehouses_screen.dart';
import 'package:accounting_system/features/reports/ui/reports_screen.dart';
import 'package:accounting_system/features/settings/ui/screens/setting_screen.dart';
import 'package:flutter/material.dart';
import 'app_route.dart';

Widget buildPage(AppRoute route) {
  return switch (route.type) {
    RouteType.dashboard => const AccountingHome(),
    RouteType.newSale => const NewDocumentScreen(kind: DocumentKind.sale),
    RouteType.sales => const DocumentListScreen(kind: DocumentKind.sale),
    RouteType.purchases => const DocumentListScreen(kind: DocumentKind.purchase),
    RouteType.saleReturns => const DocumentListScreen(kind: DocumentKind.saleReturn),
    RouteType.purchaseReturns => const DocumentListScreen(kind: DocumentKind.purchaseReturn),
    RouteType.waste => const DocumentListScreen(kind: DocumentKind.waste),
    RouteType.inventory => const InventoryScreen(),
    RouteType.products => const ProductsScreen(),
    RouteType.warehouses => const WarehousesScreen(),
    RouteType.inventoryAdjustments => const InventoryActionScreen(mode: InventoryActionMode.adjustment),
    RouteType.inventoryTransfers => const InventoryActionScreen(mode: InventoryActionMode.transfer),
    RouteType.parties => const PartiesScreen(),
    RouteType.customers => const PartiesScreen(filterType: 'customer'),
    RouteType.suppliers => const PartiesScreen(filterType: 'supplier'),
    RouteType.cashboxes => const CashScreen(mode: CashScreenMode.cashboxes),
    RouteType.expenses => const CashScreen(mode: CashScreenMode.expenses),
    RouteType.cashTransfers => const CashScreen(mode: CashScreenMode.transfers),
    RouteType.cashSessions => const CashScreen(mode: CashScreenMode.sessions),
    RouteType.financialYears => const FinancialYearsScreen(),
    RouteType.reports => const ReportsScreen(),
    RouteType.settings => const SettingsScreen(),
  };
}
