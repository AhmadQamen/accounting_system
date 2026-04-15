// lib/features/settings/domain/models/setting_model.dart
import 'package:flutter/material.dart';

@immutable
class AppSettings {
  final String language;
  final ThemeMode themeMode;

  const AppSettings({this.language = 'ar', this.themeMode = ThemeMode.system});
  static const supportedLocal = ["ar", "en", "system"];
  static const supportedTheme = ["dark", "light", "system"];
  AppSettings copyWith({String? language, ThemeMode? themeMode}) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
