import 'package:accounting_system/core/navigation/app_navigator.dart';
import 'shortcut_action.dart';

class ShortcutExecutor {
  final AppNavigator _navigator;

  ShortcutExecutor({required AppNavigator navigator}) : _navigator = navigator;

  void execute(ShortcutAction action) {
    _navigator;
  }
}
