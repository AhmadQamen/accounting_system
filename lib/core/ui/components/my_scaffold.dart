import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'background.dart';

class MyScaffold extends StatelessWidget {
  const MyScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.forceWindowsBackground = false,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool forceWindowsBackground;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final painted =
        forceWindowsBackground ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    return Scaffold(
      appBar: appBar,
      backgroundColor: painted ? colors.bgPage : Colors.transparent,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          if (painted) const AmbientBackground(),
          SafeArea(child: body),
        ],
      ),
    );
  }
}
