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

/// The full desktop sidebar: header, scrollable navigation sections, and
/// a pinned footer with the user card. Always full application height.
///
/// NOTE: the exact `RouteType` values and `AppRoute` constructor below are
/// assumptions based on the navigation controller you shared — adjust the
/// `RouteType.xxx` references and `AppRoute(...)` call to match your real
/// enum/class if the names differ.
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key});

  static final List<SidebarSectionModel> _sections = [
    SidebarSectionModel(
      title: 'التصفح',
      items: [
        SidebarItemModel(
          icon: Iconsax.shop,
          label: 'المتجر',
          routeType: RouteType.store,
        ),
        SidebarItemModel(
          icon: Iconsax.health,
          label: 'الأدوية',
          routeType: RouteType.medicines,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'المحاسبة',
      items: [
        SidebarItemModel(
          icon: Iconsax.receipt_add,
          label: 'فاتورة جديدة',
          routeType: RouteType.newInvoice,
        ),
        SidebarItemModel(
          icon: Iconsax.box_1,
          label: 'المخزون',
          routeType: RouteType.inventory,
        ),
        SidebarItemModel(
          icon: Iconsax.truck_fast,
          label: 'الموردين',
          routeType: RouteType.suppliers,
        ),
        SidebarItemModel(
          icon: Iconsax.people,
          label: 'الزبائن',
          routeType: RouteType.customers,
        ),
      ],
    ),
    SidebarSectionModel(
      title: 'الخدمات',
      items: [
        SidebarItemModel(
          icon: Iconsax.notification,
          label: 'الإشعارات',
          routeType: RouteType.notifications,
          badgeCount: 3,
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
              const SidebarHeader(),
              Divider(height: 1, thickness: 1, color: colors.border),
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
              Divider(height: 1, thickness: 1, color: colors.border),
              const SidebarFooter(
                userName: 'Maher',
                userEmail: 'maher@example.com',
                status: SubscriptionStatus.premium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
