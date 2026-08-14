import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'keyboard_action.dart';
import 'keyboard_provider.dart';

class GlobalKeyboardListener extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalKeyboardListener({super.key, required this.child});

  @override
  ConsumerState<GlobalKeyboardListener> createState() =>
      _GlobalKeyboardListenerState();
}

class _GlobalKeyboardListenerState
    extends ConsumerState<GlobalKeyboardListener> {
  late final HardwareKeyboard _keyboard;
  late final dynamic _manager;

  @override
  void initState() {
    super.initState();

    _keyboard = HardwareKeyboard.instance;
    _manager = ref.read(keyboardManagerProvider);
    _manager.on(KeyboardAction.escape, () {
      final ctx = AccountingSystem.navigatorKey.currentContext;
      final navigator = Navigator.of(ctx!);

      if (navigator.canPop()) {
        navigator.pop();
      } else {
        AppNavigation.back();
      }
    });
    _keyboard.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    _keyboard.removeHandler(_handleHardwareKey);
    _manager.off(KeyboardAction.escape);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    return _manager.handleEvent(event) == KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
