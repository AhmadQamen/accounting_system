import 'dart:io';

import 'package:flutter/material.dart';
import '../../theme/theme_extension.dart';
import 'background.dart';

/// Widget خلفية قابل لإعادة الاستخدام في جميع الصفحات
class MyScaffold extends StatefulWidget {
  /// المحتوى الذي يتم عرضه فوق الخلفية
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool forceWindowsBackground;

  const MyScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.forceWindowsBackground = false,
  });

  @override
  State<MyScaffold> createState() => _MyScaffoldState();
}

class _MyScaffoldState extends State<MyScaffold>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: widget.appBar,
      backgroundColor: widget.forceWindowsBackground || Platform.isAndroid
          ? colors.bgPage
          : Colors.transparent,
      extendBody: true,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: widget.bottomNavigationBar != null ? 60 : 0,
        ),
        child: widget.floatingActionButton,
      ),
      // bottomNavigationBar: widget.bottomNavigationBar,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Soft ambient gradient blobs (teal + amber)
          if (widget.forceWindowsBackground || Platform.isAndroid)
            AmbientBackground(),

          SafeArea(
            child: Stack(
              children: [
                widget.body,
                if (widget.bottomNavigationBar != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: widget.bottomNavigationBar!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
