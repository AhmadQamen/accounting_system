import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/setting_model.dart';

class SettingsRepository {
  static const _languageKey = 'app_language';
  static const _themeKey = 'app_theme';
  static const _notificationsKey = 'app_notifications_enabled';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      language: prefs.getString(_languageKey) ?? 'ar',
      themeMode:
          ThemeMode.values[prefs.getInt(_themeKey) ?? ThemeMode.system.index],
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_languageKey, settings.language),
      prefs.setInt(_themeKey, settings.themeMode.index),
      prefs.setBool(_notificationsKey, settings.notificationsEnabled),
    ]);
  }
}
