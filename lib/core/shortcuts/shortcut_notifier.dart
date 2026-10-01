import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyboard_shortcut_service.dart';
import 'shortcut_model.dart';

class ShortcutNotifier extends ChangeNotifier {
  final KeyboardShortcutService _service;
  List<ShortcutModel> _shortcuts = const [];
  bool _loaded = false;

  ShortcutNotifier(this._service);

  List<ShortcutModel> get shortcuts => List.unmodifiable(_shortcuts);
  bool get loaded => _loaded;

  Future<void> load() async {
    final list = await _service.getAll();
    _shortcuts = list;
    _loaded = true;
    notifyListeners();
  }

  ShortcutModel? findByKey(
    LogicalKeyboardKey key, {
    required bool ctrl,
    required bool shift,
    required bool alt,
  }) {
    for (final shortcut in _shortcuts) {
      if (shortcut.key == key &&
          shortcut.ctrl == ctrl &&
          shortcut.shift == shift &&
          shortcut.alt == alt) {
        return shortcut;
      }
    }
    return null;
  }

  Future<void> update(ShortcutModel shortcut) async {
    await _service.update(shortcut);
    await load();
  }
}
