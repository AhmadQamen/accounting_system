import 'dart:async';

import 'package:accounting_system/core/configs/breakpoints.dart';
import 'package:accounting_system/core/desktop/breadcrumb_bar.dart';
import 'package:accounting_system/core/desktop/desktop_sidebar.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/navigation/route_builder.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool get isDesktopApp =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarHover = false;
  Timer? _sidebarTimer;

  void _queueSidebarVisibility(bool visible) {
    _sidebarTimer?.cancel();
    _sidebarTimer = Timer(Duration(milliseconds: visible ? 45 : 140), () {
      if (!mounted || _sidebarHover == visible) return;
      setState(() => _sidebarHover = visible);
    });
  }

  @override
  void dispose() {
    _sidebarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(currentRouteProvider);
    if (!isDesktopApp) return buildPage(route);

    final colors = context.colors;
    return MyScaffold(
      forceWindowsBackground: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Base this on the actual shell width, not MediaQuery from the
          // feature page. This prevents the dashboard from thinking it
          // has space that is actually occupied by the sidebar.
          final compactWindow =
              constraints.maxWidth < Breakpoints.expandedSidebar;
          final visibleSidebar = _sidebarHover;
          final sidebarWidth =
              visibleSidebar
                  ? (compactWindow
                      ? Breakpoints.sidebarCollapsedWidth
                      : Breakpoints.sidebarWidth + 12)
                  : 28.0;
          final contentWidth = (constraints.maxWidth - sidebarWidth - 1).clamp(
            0.0,
            double.infinity,
          );
          final compactTopBar = contentWidth < 900;

          return Row(
            children: [
              MouseRegion(
                onEnter: (_) => _queueSidebarVisibility(true),
                onExit: (_) => _queueSidebarVisibility(false),
                child: SizedBox(
                  width: sidebarWidth,
                  height: double.infinity,
                  child:
                      visibleSidebar
                          ? DesktopSidebar(collapsed: compactWindow)
                          : Center(
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: colors.primary.withValues(alpha: .82),
                              size: 22,
                            ),
                          ),
                ),
              ),
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
                          transitionBuilder:
                              (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
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
    );
  }
}
