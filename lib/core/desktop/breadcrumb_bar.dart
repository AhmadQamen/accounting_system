import 'package:accounting_system/core/configs/breakpoints.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final routes = ref.watch(breadcrumbRoutesProvider);
    final controller = ref.read(desktopNavControllerProvider);
    final current = routes.isEmpty ? null : routes.last;

    return Container(
      height: Breakpoints.topBarHeight + 10,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: .62),
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: .82)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                compact
                    ? Text(
                      current?.title ?? 'نظام المحاسبة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                    : Row(
                      children: [
                        if (current != null)
                          Flexible(
                            child: Text(
                              current.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(routes.length, (index) {
                                final route = routes[index];
                                final last = index == routes.length - 1;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (index > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Icon(
                                          Icons.chevron_left_rounded,
                                          size: 15,
                                          color: colors.textDim,
                                        ),
                                      ),
                                    TextButton.icon(
                                      onPressed:
                                          last
                                              ? null
                                              : () => controller.popUntil(
                                                route.type,
                                              ),
                                      icon:
                                          index == 0
                                              ? const Icon(
                                                Iconsax.home_2,
                                                size: 14,
                                              )
                                              : const SizedBox.shrink(),
                                      label: Text(route.title),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                        ),
                                        foregroundColor:
                                            last
                                                ? colors.primary
                                                : colors.textSecondary,
                                        disabledForegroundColor:
                                            last
                                                ? colors.primary
                                                : colors.textDim,
                                        textStyle: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
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
          ),
          const SizedBox(width: 10),
          if (compact)
            Semantics(
              label: 'Offline‑First • البيانات محفوظة محلياً',
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.success.withValues(alpha: .16),
                  ),
                ),
                child: Center(
                  child: PulseStatusDot(
                    color: colors.success,
                    active: false,
                    size: 7,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: colors.success.withValues(alpha: .16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseStatusDot(color: colors.success, active: false, size: 7),
                  const SizedBox(width: 4),
                  Text(
                    'Offline‑First',
                    style: TextStyle(
                      color: colors.success,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
