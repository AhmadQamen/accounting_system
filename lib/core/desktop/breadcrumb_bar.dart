import 'dart:ui';

import 'package:accounting_system/core/configs/breakpoints.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    final routes = ref.watch(breadcrumbRoutesProvider);
    final controller = ref.read(desktopNavControllerProvider);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: Breakpoints.topBarHeight,
          decoration: BoxDecoration(
            color: colors.bgElevated.withValues(alpha: 0.65),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),

              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(routes.length, (index) {
                      final route = routes[index];
                      final isLast = index == routes.length - 1;

                      return Row(
                        children: [
                          _BreadcrumbItem(
                            icon: index == 0 ? Iconsax.home_2 : null,
                            label: route.title,
                            active: isLast,
                            onTap: isLast
                                ? null
                                : () => controller.popUntil(route.type),
                          ),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colors.textDim,
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatefulWidget {
  const _BreadcrumbItem({
    required this.label,
    required this.active,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  State<_BreadcrumbItem> createState() => _BreadcrumbItemState();
}

class _BreadcrumbItemState extends State<_BreadcrumbItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final clickable = widget.onTap != null;

    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hovering && clickable
                ? colors.purple.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.active ? colors.purple : colors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  color: widget.active ? colors.purple : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
