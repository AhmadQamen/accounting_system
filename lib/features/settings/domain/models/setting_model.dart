import 'package:flutter/material.dart';

@immutable
class AppSettings {
  final String language;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final double fontScale;

  const AppSettings({
    this.language = 'ar',
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.fontScale = 1,
  });

  static const supportedLocal = ["ar", "en", "system"];
  static const supportedTheme = ["dark", "light", "system"];

  AppSettings copyWith({
    String? language,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    double? fontScale,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}
