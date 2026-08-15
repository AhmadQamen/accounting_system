import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme_colors.dart';

/// Premium Coastal Meadow theme for the Offline-First accounting application.
///
/// Brand colors use Cerulean, Seagrass, Light Gold and Space Indigo while surfaces stay intentionally restrained. Luxury comes from hierarchy,
/// typography, calm surfaces and subtle motion rather than saturated effects.
abstract final class AppTheme {
  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        colors: const AppThemeColors(
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
        ),
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        colors: const AppThemeColors(
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
        ),
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppThemeColors colors,
  }) {
    final dark = brightness == Brightness.dark;
    // Use bundled system fonts on desktop. This keeps startup fully offline
    // and avoids runtime font downloads/failures. Segoe UI has strong Arabic
    // support on Windows; Tahoma/Arial are fallbacks on other platforms.
    final baseText = dark ? Typography.whiteMountainView : Typography.blackMountainView;
    final textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.7),
      headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.5),
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.4),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.25),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.4),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: Colors.white,
      secondary: colors.secondary,
      onSecondary: const Color(0xFF222E50),
      error: colors.error,
      onError: dark ? const Color(0xFF2A1512) : Colors.white,
      surface: colors.bgElevated,
      onSurface: colors.textPrimary,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bgPage,
      canvasColor: colors.bgPage,
      dividerColor: colors.border,
      disabledColor: colors.textDim,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Tahoma', 'Arial'],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [colors],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _ElegantPageTransitionBuilder(),
          TargetPlatform.macOS: _ElegantPageTransitionBuilder(),
          TargetPlatform.linux: _ElegantPageTransitionBuilder(),
          TargetPlatform.android: _ElegantPageTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.bgElevated,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 18,
        backgroundColor: colors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.muted.withValues(alpha: dark ? .72 : .52),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: inputBorder(colors.border),
        enabledBorder: inputBorder(colors.border),
        focusedBorder: inputBorder(colors.primary.withValues(alpha: .88), width: 1.5),
        errorBorder: inputBorder(colors.error.withValues(alpha: .75)),
        focusedErrorBorder: inputBorder(colors.error, width: 1.5),
        hintStyle: TextStyle(color: colors.textDim, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        errorStyle: TextStyle(color: colors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.muted,
          disabledForegroundColor: colors.textDim,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          hoverColor: Colors.transparent,
          highlightColor: colors.primary.withValues(alpha: .06),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? colors.primary : Colors.transparent;
        }),
        side: BorderSide(color: colors.border),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colors.primary : colors.textDim),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colors.primary.withValues(alpha: .25) : colors.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.muted,
        selectedColor: colors.primaryTint,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.bgElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF18213A) : const Color(0xFF222E50),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 14,
        backgroundColor: dark ? const Color(0xFF18213A) : const Color(0xFF222E50),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colors.muted.withValues(alpha: .65)),
        headingTextStyle: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12),
        dataTextStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        dividerThickness: .6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        hoverElevation: 4,
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.muted,
        circularTrackColor: colors.muted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.bgElevated,
        indicatorColor: colors.primaryTint,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.bgPage,
        indicatorColor: colors.primaryTint,
        selectedIconTheme: IconThemeData(color: colors.primary),
        selectedLabelTextStyle: TextStyle(color: colors.primary, fontWeight: FontWeight.w800),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
      ),
    );
  }
}

class _ElegantPageTransitionBuilder extends PageTransitionsBuilder {
  const _ElegantPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: Tween<double>(begin: .0, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
