import 'package:accounting_system/core/configs/breakpoints.dart';
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

bool get isDesktopApp =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(currentRouteProvider);
    if (!isDesktopApp) return buildPage(route);

    final colors = context.colors;
    return GlobalKeyboardListener(
      child: MyScaffold(
        body: PremiumBackdrop(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Base this on the actual shell width, not MediaQuery from the
              // feature page. This prevents the dashboard from thinking it
              // has space that is actually occupied by the sidebar.
              final collapsedSidebar = constraints.maxWidth < Breakpoints.expandedSidebar;
              final sidebarWidth = collapsedSidebar
                  ? Breakpoints.sidebarCollapsedWidth
                  : Breakpoints.sidebarWidth + 12;
              final contentWidth = (constraints.maxWidth - sidebarWidth - 1).clamp(0.0, double.infinity);
              final compactTopBar = contentWidth < 900;

              return Row(
                children: [
                  DesktopSidebar(collapsed: collapsedSidebar),
                  Container(width: 1, color: colors.border.withValues(alpha: .8)),
                  Expanded(
                    child: Column(
                      children: [
                        BreadcrumbBar(compact: compactTopBar),
                        Expanded(
                          child: ClipRect(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              reverseDuration: const Duration(milliseconds: 140),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(opacity: animation, child: child),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
