import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard_action.dart';
import '../keyboard_handler.dart';
import '../keyboard_manager.dart';

class InvoiceKeyboardHandler implements KeyboardHandler {
  @override
  KeyEventResult handleKeyEvent(KeyEvent event, KeyboardManager manager) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.enter,
    )) {
      manager.trigger(KeyboardAction.invoiceSubmit);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
