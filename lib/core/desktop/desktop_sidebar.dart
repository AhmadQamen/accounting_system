import 'dart:ui';
import 'package:accounting_system/core/configs/breakpoints.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'sidebar_footer.dart';
import 'sidebar_header.dart';
import 'sidebar_item.dart';
import 'sidebar_section.dart';

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key});

  static final List<SidebarSectionModel> _sections = [
    SidebarSectionModel(
      title: 'الرئيسية',
      items: [
        SidebarItemModel(
          icon: Iconsax.home_2,
          label: 'لوحة التحكم',
          routeType: RouteType.dashboard,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'المبيعات',
      items: [
        SidebarItemModel(
          icon: Iconsax.receipt_add,
          label: 'فاتورة بيع',
          routeType: RouteType.newSale,
        ),
        SidebarItemModel(
          icon: Iconsax.receipt_1,
          label: 'سجل المبيعات',
          routeType: RouteType.sales,
        ),
        SidebarItemModel(
          icon: Iconsax.rotate_left,
          label: 'مرتجعات البيع',
          routeType: RouteType.saleReturns,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'المشتريات',
      items: [
        SidebarItemModel(
          icon: Iconsax.shopping_cart,
          label: 'المشتريات',
          routeType: RouteType.purchases,
        ),
        SidebarItemModel(
          icon: Iconsax.undo,
          label: 'مرتجعات الشراء',
          routeType: RouteType.purchaseReturns,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'المخزون',
      items: [
        SidebarItemModel(
          icon: Iconsax.box_1,
          label: 'المخزون',
          routeType: RouteType.inventory,
        ),
        SidebarItemModel(
          icon: Iconsax.box,
          label: 'المنتجات',
          routeType: RouteType.products,
        ),
        SidebarItemModel(
          icon: Iconsax.buildings_2,
          label: 'المستودعات',
          routeType: RouteType.warehouses,
        ),
        SidebarItemModel(
          icon: Iconsax.clipboard_tick,
          label: 'الجرد والتسويات',
          routeType: RouteType.inventoryAdjustments,
        ),
        SidebarItemModel(
          icon: Iconsax.arrange_square,
          label: 'تحويل مستودعات',
          routeType: RouteType.inventoryTransfers,
        ),
        SidebarItemModel(
          icon: Iconsax.warning_2,
          label: 'الهالك',
          routeType: RouteType.waste,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'الحسابات',
      items: [
        SidebarItemModel(
          icon: Iconsax.people,
          label: 'الأطراف',
          routeType: RouteType.parties,
        ),
        SidebarItemModel(
          icon: Iconsax.user_tick,
          label: 'العملاء',
          routeType: RouteType.customers,
        ),
        SidebarItemModel(
          icon: Iconsax.truck_fast,
          label: 'الموردون',
          routeType: RouteType.suppliers,
        ),
        SidebarItemModel(
          icon: Iconsax.wallet_money,
          label: 'الصناديق',
          routeType: RouteType.cashboxes,
        ),
        SidebarItemModel(
          icon: Iconsax.money_send,
          label: 'المصروفات',
          routeType: RouteType.expenses,
        ),
        SidebarItemModel(
          icon: Iconsax.convert_card,
          label: 'تحويلات الصندوق',
          routeType: RouteType.cashTransfers,
        ),
        SidebarItemModel(
          icon: Iconsax.clock,
          label: 'جلسات الصندوق',
          routeType: RouteType.cashSessions,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'النظام',
      items: [
        SidebarItemModel(
          icon: Iconsax.chart_2,
          label: 'التقارير',
          routeType: RouteType.reports,
        ),
        SidebarItemModel(
          icon: Iconsax.calendar_1,
          label: 'السنوات المالية',
          routeType: RouteType.financialYears,
        ),
        SidebarItemModel(
          icon: Iconsax.setting_2,
          label: 'الإعدادات',
          routeType: RouteType.settings,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentRoute = ref.watch(currentRouteProvider);
    final navController = ref.read(desktopNavControllerProvider);
    return SizedBox(
      width: Breakpoints.sidebarWidth,
      height: double.infinity,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            children: [
              const SidebarHeader(
                appName: 'Accounting System',
                subtitle: 'Offline Accounting',
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 16),
                  children: [
                    for (final section in _sections)
                      SidebarSection(
                        section: section,
                        currentRouteType: currentRoute.type,
                        onItemTap: (type) =>
                            navController.push(AppRoute(type: type)),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              const SidebarFooter(
                userName: 'Local Admin',
                userEmail: 'Offline first',
                status: SubscriptionStatus.premium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
