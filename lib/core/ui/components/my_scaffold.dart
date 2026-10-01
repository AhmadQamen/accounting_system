import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'background.dart';

/// Shared page scaffold for the whole application.
///
/// Feature screens should use this component rather than creating raw
/// [Scaffold] widgets. Keeping the surface/background behavior here prevents
/// page-to-page differences and makes future responsive changes centralized.
class MyScaffold extends StatelessWidget {
  const MyScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.forceWindowsBackground = false,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.safeArea = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool forceWindowsBackground;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    // Desktop pages are hosted by AppShell, which paints one continuous
    // application backdrop. Painting again here made the artwork appear in
    // dialogs and individual pages instead of behind the whole app.
    final paintBackground = forceWindowsBackground || isAndroid;

    final pageBody = Stack(
      fit: StackFit.expand,
      children: [
        if (paintBackground) const AmbientBackground(),
        safeArea ? SafeArea(child: body) : body,
      ],
    );

    return Scaffold(
      appBar: appBar,
      // Navigation on mobile is intentionally provided by the dashboard cards,
      // not a drawer that competes with the compact working screens.
      drawer: drawer,
      endDrawer: endDrawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: paintBackground ? colors.bgPage : Colors.transparent,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: pageBody,
    );
  }
}
