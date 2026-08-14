import 'package:flutter/material.dart';

import 'keyboard_manager.dart';

abstract class KeyboardHandler {
  KeyEventResult handleKeyEvent(KeyEvent event, KeyboardManager manager);
}
