import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_theme_colors.dart';

/// Main theme for the Offline-First accounting application.
///
/// Brand palette:
/// - Primary:   #D4A373 (Warm Sand)
/// - Secondary: #CCD5AE (Soft Sage)
///
/// The old token names `purple` and `amber` are intentionally preserved in
/// AppThemeColors to avoid breaking the existing project structure/usages.
abstract final class AppTheme {
  /// Dark theme for the accounting app.
  static ThemeData get dark {
    const ext = AppThemeColors(
      bgDeep: AppColors.bgDeep,
      bgPage: AppColors.bgPage,
      bgElevated: AppColors.bgElevated,
      border: AppColors.border,
      borderPurple: AppColors.borderPurple,
      purple: AppColors.purple,
      purpleLight: AppColors.purpleLight,
      purpleTint: AppColors.purpleTint,
      purpleDim: AppColors.purpleDim,
      amber: AppColors.amber,
      amberTint: AppColors.amberTint,
      amberDim: AppColors.amberDim,
      blue: AppColors.blue,
      blueLight: AppColors.blueLight,
      blueDark: AppColors.blueDark,
      blueDim: AppColors.blueDim,
      success: AppColors.success,
      successDim: AppColors.successDim,
      error: AppColors.error,
      errorLight: AppColors.errorLight,
      errorDark: AppColors.errorDark,
      errorDim: AppColors.errorDim,
      muted: AppColors.muted,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textDim: AppColors.textDim,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ext.bgPage,
      colorScheme: ColorScheme.dark(
        primary: ext.purple,
        secondary: ext.amber,
        surface: ext.bgElevated,
        onSurface: ext.textPrimary,
        onPrimary: const Color(0xFF2F241A),
        onSecondary: const Color(0xFF26301F),
        error: ext.error,
        onError: const Color(0xFF2A1512),
      ),
      extensions: const [ext],
      dividerColor: ext.border,
      textTheme: GoogleFonts.tajawalTextTheme(Typography.whiteCupertino),
      primaryTextTheme: GoogleFonts.tajawalTextTheme(Typography.whiteCupertino),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: ext.bgPage,
        foregroundColor: ext.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: ext.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: ext.textDim),
        errorStyle: TextStyle(color: ext.error),
      ),
      iconTheme: IconThemeData(color: ext.textPrimary),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ext.purple;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: ext.border),
        checkColor: WidgetStateProperty.all(const Color(0xFF2F241A)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ext.purple,
          foregroundColor: const Color(0xFF2F241A),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ext.purpleLight),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.textPrimary,
          side: BorderSide(color: ext.borderPurple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple,
        foregroundColor: Color(0xFF2F241A),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ext.bgElevated,
        indicatorColor: ext.purpleTint,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: ext.textPrimary),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ext.bgPage,
        indicatorColor: ext.purpleTint,
        selectedIconTheme: IconThemeData(color: ext.purpleLight),
        unselectedIconTheme: IconThemeData(color: ext.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ext.purple,
        linearTrackColor: ext.muted,
        circularTrackColor: ext.muted,
      ),
    );
  }

  /// Light theme for the accounting app.
  static ThemeData get light {
    const ext = AppThemeColors(
      bgDeep: AppLightColors.bgDeep,
      bgPage: AppLightColors.bgPage,
      bgElevated: AppLightColors.bgElevated,
      border: AppLightColors.border,
      borderPurple: AppLightColors.borderPurple,
      purple: AppLightColors.purple,
      purpleLight: AppLightColors.purpleLight,
      purpleTint: AppLightColors.purpleTint,
      purpleDim: AppLightColors.purpleDim,
      amber: AppLightColors.amber,
      amberTint: AppLightColors.amberTint,
      amberDim: AppLightColors.amberDim,
      blue: AppLightColors.blue,
      blueLight: AppLightColors.blueLight,
      blueDark: AppLightColors.blueDark,
      blueDim: AppLightColors.blueDim,
      success: AppLightColors.success,
      successDim: AppLightColors.successDim,
      error: AppLightColors.error,
      errorLight: AppLightColors.errorLight,
      errorDark: AppLightColors.errorDark,
      errorDim: AppLightColors.errorDim,
      muted: AppLightColors.muted,
      textPrimary: AppLightColors.textPri,
      textSecondary: AppLightColors.textSec,
      textDim: AppLightColors.textDim,
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: ext.bgPage,
      colorScheme: ColorScheme.light(
        primary: ext.purple,
        secondary: ext.amber,
        surface: ext.bgElevated,
        onSurface: ext.textPrimary,
        onPrimary: const Color(0xFF2F241A),
        onSecondary: const Color(0xFF26301F),
        error: ext.error,
        onError: Colors.white,
      ),
      extensions: const [ext],
      dividerColor: ext.border,
      textTheme: GoogleFonts.tajawalTextTheme(Typography.blackCupertino),
      primaryTextTheme: GoogleFonts.tajawalTextTheme(Typography.blackCupertino),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: ext.bgPage,
        foregroundColor: ext.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: ext.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ext.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: ext.textDim),
        errorStyle: TextStyle(color: ext.error),
      ),
      iconTheme: IconThemeData(color: ext.textPrimary),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ext.purple;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: ext.border),
        checkColor: WidgetStateProperty.all(const Color(0xFF2F241A)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: ext.purple,
          foregroundColor: const Color(0xFF2F241A),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ext.purple),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.textPrimary,
          side: BorderSide(color: ext.borderPurple),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppLightColors.purple,
        foregroundColor: Color(0xFF2F241A),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ext.bgElevated,
        indicatorColor: ext.purpleTint,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: ext.textPrimary),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ext.bgPage,
        indicatorColor: ext.purpleTint,
        selectedIconTheme: IconThemeData(color: ext.purple),
        unselectedIconTheme: IconThemeData(color: ext.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ext.purple,
        linearTrackColor: ext.muted,
        circularTrackColor: ext.muted,
      ),
    );
  }
}
