import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bgDeep;
  final Color bgPage;
  final Color bgElevated;

  final Color border;
  final Color borderPurple;

  // Primary brand color — kept as `purple` for backward compatibility.
  final Color purple;
  final Color purpleLight;
  final Color purpleTint;
  final Color purpleDim;

  // Secondary brand color — kept as `amber` for backward compatibility.
  final Color amber;
  final Color amberTint;
  final Color amberDim;

  // 🔵 Information / processing
  final Color blue;
  final Color blueLight;
  final Color blueDark;
  final Color blueDim;

  // 🟩 Success / completed
  final Color success;
  final Color successDim;

  // 🔴 Error / destructive
  final Color error;
  final Color errorLight;
  final Color errorDark;
  final Color errorDim;

  final Color muted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;

  Color get primary => purple;
  Color get secondary => amber;
  Color get surface => bgPage;
  Color get surfaceElevated => bgElevated;
  Color get warning => amber;
  Color get info => blue;

  const AppThemeColors({
    required this.bgDeep,
    required this.bgPage,
    required this.bgElevated,
    required this.border,
    required this.borderPurple,
    required this.purple,
    required this.purpleLight,
    required this.purpleTint,
    required this.purpleDim,
    required this.amber,
    required this.amberTint,
    required this.amberDim,
    required this.blue,
    required this.blueLight,
    required this.blueDark,
    required this.blueDim,
    required this.success,
    required this.successDim,
    required this.error,
    required this.errorLight,
    required this.errorDark,
    required this.errorDim,
    required this.muted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
  });

  @override
  AppThemeColors copyWith({
    Color? bgDeep,
    Color? bgPage,
    Color? bgElevated,
    Color? border,
    Color? borderPurple,
    Color? purple,
    Color? purpleLight,
    Color? purpleTint,
    Color? purpleDim,
    Color? amber,
    Color? amberTint,
    Color? amberDim,
    Color? blue,
    Color? blueLight,
    Color? blueDark,
    Color? blueDim,
    Color? success,
    Color? successDim,
    Color? error,
    Color? errorLight,
    Color? errorDark,
    Color? errorDim,
    Color? muted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDim,
  }) {
    return AppThemeColors(
      bgDeep: bgDeep ?? this.bgDeep,
      bgPage: bgPage ?? this.bgPage,
      bgElevated: bgElevated ?? this.bgElevated,
      border: border ?? this.border,
      borderPurple: borderPurple ?? this.borderPurple,
      purple: purple ?? this.purple,
      purpleLight: purpleLight ?? this.purpleLight,
      purpleTint: purpleTint ?? this.purpleTint,
      purpleDim: purpleDim ?? this.purpleDim,
      amber: amber ?? this.amber,
      amberTint: amberTint ?? this.amberTint,
      amberDim: amberDim ?? this.amberDim,
      blue: blue ?? this.blue,
      blueLight: blueLight ?? this.blueLight,
      blueDark: blueDark ?? this.blueDark,
      blueDim: blueDim ?? this.blueDim,
      success: success ?? this.success,
      successDim: successDim ?? this.successDim,
      error: error ?? this.error,
      errorLight: errorLight ?? this.errorLight,
      errorDark: errorDark ?? this.errorDark,
      errorDim: errorDim ?? this.errorDim,
      muted: muted ?? this.muted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDim: textDim ?? this.textDim,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    covariant ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) return this;

    return AppThemeColors(
      bgDeep: Color.lerp(bgDeep, other.bgDeep, t)!,
      bgPage: Color.lerp(bgPage, other.bgPage, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderPurple: Color.lerp(borderPurple, other.borderPurple, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      purpleLight: Color.lerp(purpleLight, other.purpleLight, t)!,
      purpleTint: Color.lerp(purpleTint, other.purpleTint, t)!,
      purpleDim: Color.lerp(purpleDim, other.purpleDim, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberTint: Color.lerp(amberTint, other.amberTint, t)!,
      amberDim: Color.lerp(amberDim, other.amberDim, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueLight: Color.lerp(blueLight, other.blueLight, t)!,
      blueDark: Color.lerp(blueDark, other.blueDark, t)!,
      blueDim: Color.lerp(blueDim, other.blueDim, t)!,
      success: Color.lerp(success, other.success, t)!,
      successDim: Color.lerp(successDim, other.successDim, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      errorDark: Color.lerp(errorDark, other.errorDark, t)!,
      errorDim: Color.lerp(errorDim, other.errorDim, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
    );
  }
}
