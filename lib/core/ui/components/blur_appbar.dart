import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlurAppbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final bool? centerTitle;
  final List<Widget>? actions;
  final Color? foregroundColor;
  const BlurAppbar(
      {super.key,
      this.title,
      this.actions,
      this.leading,
      this.centerTitle,
      this.foregroundColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDarkMode = theme.brightness == Brightness.dark;
    final style =
        isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            forceMaterialTransparency: true,
            leading: leading,
            foregroundColor: foregroundColor,
            systemOverlayStyle: style,
            centerTitle: centerTitle,
            backgroundColor: Colors.transparent,
            elevation: 10,
            shadowColor: Colors.black,
            title: title,
            actions: actions,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
