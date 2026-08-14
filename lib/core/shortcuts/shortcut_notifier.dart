import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyboard_shortcut_service.dart';
import 'shortcut_model.dart';

class ShortcutNotifier extends ChangeNotifier {
  final KeyboardShortcutService _service;
  Map<LogicalKeyboardKey, ShortcutModel> _shortcuts = {};
  bool _loaded = false;

  ShortcutNotifier(this._service);

  Map<LogicalKeyboardKey, ShortcutModel> get shortcuts => _shortcuts;
  bool get loaded => _loaded;

  Future<void> load() async {
    final list = await _service.getAll();
    _shortcuts = {for (final s in list) s.key: s};
    _loaded = true;
    notifyListeners();
  }

  ShortcutModel? findByKey(LogicalKeyboardKey key) {
    return _shortcuts[key];
  }
}
