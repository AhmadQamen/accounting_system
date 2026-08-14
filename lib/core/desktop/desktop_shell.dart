import 'dart:io' show Platform;

import 'package:accounting_system/core/keyboard/global_keyboard_listener.dart';
import 'package:accounting_system/core/navigation/desktop_navigation_controller.dart';
import 'package:accounting_system/core/navigation/route_builder.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/features/accounting/ui/screens/accounting_home.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'breadcrumb_bar.dart';
import 'desktop_sidebar.dart';

/// True only for a real Windows desktop build — never web, never
/// macOS/Linux, never mobile. This is intentionally stricter than the
/// generic "is this a desktop platform" checks used elsewhere in the app,
/// because the sidebar is a Windows-only navigation shell.
bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

/// Wraps the app's routed content.
///
/// - **Windows**: renders the fixed [DesktopSidebar] on the side plus the
///   current page content, laid out as a classic IDE-style shell.
/// - **Every other platform** (Android, iOS, macOS, Linux, web): renders
///   [child] on its own — no sidebar. Those platforms are expected to use
///   their own navigation (e.g. `MyBottomNavBar`) elsewhere in the tree.
///
/// [child] is the currently active page content — however your router
/// resolves it (go_router, the `DesktopNavigationController` you already
/// have, etc). This widget only decides *whether* to wrap it with a
/// sidebar, not *what* the page content is.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (!isWindowsDesktop) {
      // Mobile / other platforms: no sidebar, content owns the whole screen.
      return AccountingHome();
    }

    final route = ref.read(desktopNavControllerProvider).current;

    return GlobalKeyboardListener(
      child: MyScaffold(
        forceWindowsBackground: true,
        body: Row(
          children: [
            const DesktopSidebar(),
            Container(width: 1, color: colors.border),
            Expanded(
              child: Column(
                children: [
                  BreadcrumbBar(),
                  Expanded(
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (widget, animation) =>
                            FadeTransition(opacity: animation, child: widget),
                        child: KeyedSubtree(
                          // Re-keying on child forces the fade transition to
                          // play when the routed page actually changes.
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
    );
  }
}
