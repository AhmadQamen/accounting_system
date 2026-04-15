// lib/features/settings/presentation/controllers/settings_controller.dart
import 'package:accounting_system/features/settings/domain/models/setting_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/repo/setting_repo.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
      return SettingsNotifier(ref);
    });

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository = SettingsRepository();
  final Ref ref;

  SettingsNotifier(this.ref) : super(const AppSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = await _repository.loadSettings();
  }

  Future<void> _saveAndUpdate(AppSettings newSettings) async {
    await _repository.saveSettings(newSettings);
    state = newSettings;
  }

  void changeLanguage(String language) {
    _saveAndUpdate(state.copyWith(language: language));
  }

  void changeTheme(ThemeMode themeMode) {
    _saveAndUpdate(state.copyWith(themeMode: themeMode));
  }
}
