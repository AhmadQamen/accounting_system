import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'sidebar_item.dart';

/// Renders a [SidebarSectionModel]: a small uppercase-style title followed
/// by its list of [DesktopSidebarItem]s.
class SidebarSection extends StatelessWidget {
  const SidebarSection({
    super.key,
    required this.section,
    required this.currentRouteType,
    required this.onItemTap,
    this.collapsed = false,
  });

  final SidebarSectionModel section;
  final RouteType currentRouteType;
  final ValueChanged<RouteType> onItemTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                section.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                for (final item in section.items) ...[
                  DesktopSidebarItem(
                    icon: item.icon,
                    label: item.label,
                    badgeCount: item.badgeCount,
                    collapsed: collapsed,
                    selected: item.routeType == currentRouteType,
                    onTap: () => onItemTap(item.routeType),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled group of [SidebarItemModel]s (e.g. "التصفح", "المحاسبة").
@immutable
class SidebarSectionModel {
  const SidebarSectionModel({required this.title, required this.items});

  final String title;
  final List<SidebarItemModel> items;
}
