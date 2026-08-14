import 'package:accounting_system/core/shortcuts/shortcut_executor.dart';
import 'package:accounting_system/core/shortcuts/shortcut_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'barcode_reader.dart';
import 'handlers/dialog_handler.dart';
import 'handlers/global_handler.dart';
import 'handlers/invoice_handler.dart';
import 'keyboard_action.dart';
import 'keyboard_context.dart';
import 'keyboard_handler.dart';

class KeyboardManager {
  final ShortcutNotifier shortcuts;
  final ShortcutExecutor executor;

  KeyboardManager({required this.shortcuts, required this.executor}) {
    _handlers.addAll({
      KeyboardContext.dialog: DialogKeyboardHandler(),
      KeyboardContext.invoice: InvoiceKeyboardHandler(),
      KeyboardContext.global: GlobalKeyboardHandler(),
    });
  }

  //──────────────────────────────────────────────
  // Context Registration
  //──────────────────────────────────────────────

  final Map<Object, KeyboardContext> _registrations = {};

  KeyboardContext get current {
    if (_registrations.isEmpty) {
      return KeyboardContext.global;
    }

    return _registrations.values.reduce(
      (a, b) => a.priority >= b.priority ? a : b,
    );
  }

  void register(Object owner, KeyboardContext context) {
    _registrations[owner] = context;
  }

  void unregister(Object owner) {
    _registrations.remove(owner);
  }

  //──────────────────────────────────────────────
  // Context Handlers
  //──────────────────────────────────────────────

  final Map<KeyboardContext, KeyboardHandler> _handlers = {};

  void registerHandler(KeyboardContext context, KeyboardHandler handler) {
    _handlers[context] = handler;
  }

  //──────────────────────────────────────────────
  // Actions
  //──────────────────────────────────────────────

  final Map<KeyboardAction, VoidCallback> _callbacks = {};

  void on(KeyboardAction action, VoidCallback callback) {
    _callbacks[action] = callback;
  }

  void off(KeyboardAction action) {
    _callbacks.remove(action);
  }

  bool hasHandler(KeyboardAction action) {
    return _callbacks.containsKey(action);
  }

  void trigger(KeyboardAction action) {
    _callbacks[action]?.call();
  }

  //──────────────────────────────────────────────
  // Barcode
  //──────────────────────────────────────────────

  final BarcodeReader barcodeReader = BarcodeReader();

  //──────────────────────────────────────────────
  // Main Dispatcher
  //──────────────────────────────────────────────

  KeyEventResult handleEvent(KeyEvent event) {
    // Ignore KeyUp / Repeats
    if (event is! KeyDownEvent || event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // إذا كان المستخدم يكتب داخل TextField
    // لا نتدخل إطلاقاً.
    final focused = FocusManager.instance.primaryFocus;

    final editingText =
        focused?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

    if (editingText) {
      return KeyEventResult.ignored;
    }

    // Barcode له الأولوية
    if (barcodeReader.isEnabled) {
      final result = barcodeReader.handleKeyEvent(event);

      if (result == KeyEventResult.handled) {
        return result;
      }
    }

    // Context Handler
    final handler = _handlers[current];

    if (handler != null) {
      final result = handler.handleKeyEvent(event, this);
      if (result == KeyEventResult.handled) {
        return result;
      }
    }

    // Shortcut
    if (shortcuts.loaded) {
      final shortcut = shortcuts.findByKey(event.logicalKey);
      if (shortcut != null) {
        executor.execute(shortcut.action);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
