import 'dart:ui';

import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared translucent app bar used by feature pages.
///
/// Keep feature screens on this component instead of constructing a raw
/// [AppBar] so desktop/mobile presentation stays consistent in one place.
class BlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BlurAppBar({
    super.key,
    this.title,
    this.leading,
    this.centerTitle,
    this.actions,
    this.foregroundColor,
    this.bottom,
    this.toolbarHeight = kToolbarHeight,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final Widget? leading;
  final bool? centerTitle;
  final List<Widget>? actions;
  final Color? foregroundColor;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: automaticallyImplyLeading,
          leading: leading,
          foregroundColor: foregroundColor ?? colors.textPrimary,
          systemOverlayStyle: overlayStyle,
          centerTitle: centerTitle,
          backgroundColor: colors.bgPage.withValues(alpha: .78),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: toolbarHeight,
          title: title,
          actions: actions,
          bottom: bottom,
          shape: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: .72)),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}

/// Backwards-compatible spelling from the original project.
class BlurAppbar extends BlurAppBar {
  const BlurAppbar({
    super.key,
    super.title,
    super.leading,
    super.centerTitle,
    super.actions,
    super.foregroundColor,
    super.bottom,
    super.toolbarHeight,
    super.automaticallyImplyLeading,
  });
}
