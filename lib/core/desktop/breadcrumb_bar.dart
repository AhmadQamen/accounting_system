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
    return Container(
      height: Breakpoints.topBarHeight,
      color: colors.bgElevated.withValues(alpha: .75),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(routes.length, (index) {
                  final route = routes[index];
                  final last = index == routes.length - 1;
                  return Row(
                    children: [
                      TextButton.icon(
                        onPressed: last
                            ? null
                            : () => controller.popUntil(route.type),
                        icon: Icon(
                          index == 0
                              ? Iconsax.home_2
                              : Icons.chevron_right_rounded,
                          size: 16,
                        ),
                        label: Text(route.title),
                        style: TextButton.styleFrom(
                          foregroundColor: last
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
