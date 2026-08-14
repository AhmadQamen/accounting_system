import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';

class DesktopSidebarItem extends StatefulWidget {
  const DesktopSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
    this.collapsed = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  final int? badgeCount;

  /// إذا كان الـ Sidebar مصغراً.
  final bool collapsed;

  @override
  State<DesktopSidebarItem> createState() => _DesktopSidebarItemState();
}

class _DesktopSidebarItemState extends State<DesktopSidebarItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final accent = widget.selected
        ? colors.purple
        : hovering
        ? colors.textPrimary
        : colors.textSecondary;

    final background = widget.selected
        ? colors.purple.withValues(alpha: .12)
        : hovering
        ? colors.purple.withValues(alpha: .05)
        : Colors.transparent;

    final border = widget.selected
        ? colors.purple.withValues(alpha: .30)
        : Colors.transparent;

    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: widget.collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(widget.icon, size: 22, color: accent),

              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: _Badge(count: widget.badgeCount!),
                ),
            ],
          ),

          if (!widget.collapsed) ...[
            const SizedBox(width: 14),

            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.collapsed) {
      child = Tooltip(message: widget.label, child: child);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(99),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Static description of a single sidebar item (icon, label, target route).
///
/// This is pure data — no widget state lives here. [DesktopSidebar] maps
/// each [SidebarItemModel] to a `DesktopSidebarItem` widget and wires up
/// selection + navigation.
@immutable
class SidebarItemModel {
  const SidebarItemModel({
    required this.icon,
    required this.label,
    required this.routeType,
    this.badgeCount,
  });

  final IconData icon;
  final String label;

  /// The route this item navigates to. Used both for `onTap` (via the
  /// navigation controller) and to determine the "selected" state by
  /// comparing against the current route's type.
  final RouteType routeType;

  /// Optional notification-style badge (e.g. unread count).
  final int? badgeCount;
}
