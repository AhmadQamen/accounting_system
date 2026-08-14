import 'package:flutter/material.dart';

@immutable
class AppSettings {
  final String language;
  final ThemeMode themeMode;
  final bool notificationsEnabled;

  const AppSettings({
    this.language = 'ar',
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
  });

  static const supportedLocal = ["ar", "en", "system"];
  static const supportedTheme = ["dark", "light", "system"];

  AppSettings copyWith({
    String? language,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
