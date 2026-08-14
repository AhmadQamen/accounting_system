import 'package:flutter/material.dart';
import 'app_theme_colors.dart';

/// Convenience accessors used across the accounting app.
/// Keeps the same API as the previous project.
extension ThemeGetter on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
}
