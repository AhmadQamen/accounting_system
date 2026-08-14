import 'package:accounting_system/features/accounting/ui/screens/accounting_home.dart';
import 'package:flutter/material.dart';
import 'app_route.dart';

Widget buildPage(AppRoute route) {
  return AccountingHome();
  // switch (route.type) {
  //   // ── Main ─────────────────────────────────────

  //   case RouteType.home:
  //     return const PharmacyHome();

  //   case RouteType.accounting:
  //     return const AccountingHampage();

  //   case RouteType.warehouse:
  //     return WarehouseHome(
  //       user:
  //           ref?.read(authNotifierProvider).currentUser ??
  //           (throw UnsupportedError('WarehouseRoute requires WidgetRef')),
  //     );

  //   // ── Sale ─────────────────────────────────────

  //   case RouteType.saleDashboard:
  //     return const SaleDashboardPage();

  //   case RouteType.createSale:
  //     return const CreateSalePage();

  //   case RouteType.saleDetails:
  //     final args = route.args as SaleDetailsArgs;

  //     return SaleDetailsPage(
  //       saleId: args.saleId,
  //       showFinalSale: args.showFinalSale,
  //     );

  //   // ── Customer ─────────────────────────────────

  //   case RouteType.customerDetails:
  //     return CustomerDetailsPage(customer: route.args as Customer);

  //   // ── Settings ─────────────────────────────────

  //   case RouteType.settings:
  //     return const Setting();
  // }
}
