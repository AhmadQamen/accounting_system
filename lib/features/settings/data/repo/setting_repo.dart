import 'package:accounting_system/features/settings/domain/models/setting_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _languageKey = 'app_language';
  static const _themeKey = 'app_theme';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      language: prefs.getString(_languageKey) ?? 'ar',
      themeMode:
          ThemeMode.values[prefs.getInt(_themeKey) ?? ThemeMode.system.index],
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_languageKey, settings.language),
      prefs.setInt(_themeKey, settings.themeMode.index),
    ]);
  }
}
