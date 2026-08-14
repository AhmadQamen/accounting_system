import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard_action.dart';
import '../keyboard_handler.dart';
import '../keyboard_manager.dart';

class GlobalKeyboardHandler implements KeyboardHandler {
  @override
  KeyEventResult handleKeyEvent(KeyEvent event, KeyboardManager manager) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      manager.trigger(KeyboardAction.escape);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
