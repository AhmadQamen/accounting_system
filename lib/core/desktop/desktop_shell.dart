import 'package:accounting_system/core/desktop/breadcrumb_bar.dart';
import 'package:accounting_system/core/desktop/desktop_sidebar.dart';
import 'package:accounting_system/core/keyboard/global_keyboard_listener.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/navigation/route_builder.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool get isWindowsDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(currentRouteProvider);
    if (!isWindowsDesktop) return buildPage(route);

    final colors = context.colors;
    return GlobalKeyboardListener(
      child: MyScaffold(
        forceWindowsBackground: true,
        body: PremiumBackdrop(
          child: Row(
            children: [
              const DesktopSidebar(),
              Container(width: 1, color: colors.border.withValues(alpha: .8)),
              Expanded(
                child: Column(
                  children: [
                    const BreadcrumbBar(),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          reverseDuration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(
                              begin: const Offset(0, .018),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(position: slide, child: child),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(route.type),
                            child: buildPage(route),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
