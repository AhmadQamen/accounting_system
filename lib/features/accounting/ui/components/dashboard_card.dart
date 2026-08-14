import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extension.dart';

/// ============================================
/// 🟣 DASHBOARD CARD — icon + title, no container
/// ============================================
/// Minimal by design: just a big icon tile and a title underneath,
/// no card background, border, or shadow around the whole item — it
/// sits directly on the page/grid background.
///
/// Hover feedback lives entirely on the icon tile (scale + tint) and
/// the label (color shift), so the interaction is still clear without
/// needing a boxed container. Motion is a single 150ms ease — no
/// loops, nothing left animating.
class DashboardCard extends StatefulWidget {
  const DashboardCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;

  /// Accent color for this item (icon tile + hover tint).
  final Color color;
  final VoidCallback onTap;

  /// Optional numeric badge shown on the icon's corner (e.g. pending count).
  final int? badgeCount;

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = widget.color;
    final scale = _pressed ? 0.94 : (_hovering ? 1.06 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: _hovering ? 0.26 : 0.16),
                          color.withValues(alpha: _hovering ? 0.12 : 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: _hovering ? 0.30 : 0.16),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.icon, color: color, size: 28),
                  ),
                ),
                if (widget.badgeCount != null && widget.badgeCount! > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _CountBadge(count: widget.badgeCount!),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _hovering ? color : colors.textPrimary,
                height: 1.2,
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.bgPage, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.error.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
