import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
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
  final bool collapsed;

  @override
  State<DesktopSidebarItem> createState() => _DesktopSidebarItemState();
}

class _DesktopSidebarItemState extends State<DesktopSidebarItem> {
  bool hovering = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.selected ? colors.primary : hovering ? colors.textPrimary : colors.textSecondary;
    final background = widget.selected
        ? colors.primary.withValues(alpha: .105)
        : hovering
            ? colors.muted.withValues(alpha: .72)
            : Colors.transparent;

    Widget child = AnimatedScale(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      scale: pressed ? .985 : 1,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected ? colors.primary.withValues(alpha: .18) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppMotion.normal,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.selected ? colors.primary.withValues(alpha: .12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(widget.icon, size: 19, color: accent),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    PositionedDirectional(top: -3, end: -5, child: _Badge(count: widget.badgeCount!)),
                ],
              ),
            ),
            if (!widget.collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.normal,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              AnimatedOpacity(
                duration: AppMotion.fast,
                opacity: widget.selected ? 1 : 0,
                child: Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(color: colors.primary.withValues(alpha: .28), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.collapsed) child = Tooltip(message: widget.label, child: child);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() {
        hovering = false;
        pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
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
        border: Border.all(color: colors.bgElevated, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, height: 1),
      ),
    );
  }
}

@immutable
class SidebarItemModel {
  const SidebarItemModel({required this.icon, required this.label, required this.routeType, this.badgeCount});
  final IconData icon;
  final String label;
  final RouteType routeType;
  final int? badgeCount;
}
