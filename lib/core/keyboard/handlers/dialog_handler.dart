import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard_action.dart';
import '../keyboard_handler.dart';
import '../keyboard_manager.dart';

class DialogKeyboardHandler implements KeyboardHandler {
  @override
  KeyEventResult handleKeyEvent(KeyEvent event, KeyboardManager manager) {
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      manager.trigger(KeyboardAction.dialogSubmit);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
