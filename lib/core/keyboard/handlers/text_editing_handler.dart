import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard_handler.dart';
import '../keyboard_manager.dart';

class TextEditingKeyboardHandler implements KeyboardHandler {
  @override
  KeyEventResult handleKeyEvent(KeyEvent event, KeyboardManager manager) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
