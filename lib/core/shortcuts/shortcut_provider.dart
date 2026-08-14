import 'package:accounting_system/core/navigation/app_navigator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'keyboard_shortcut_service.dart';
import 'shortcut_executor.dart';
import 'shortcut_notifier.dart';

final keyboardShortcutServiceProvider = Provider<KeyboardShortcutService>((
  ref,
) {
  return KeyboardShortcutService.instance;
});

final shortcutNotifierProvider = ChangeNotifierProvider<ShortcutNotifier>((
  ref,
) {
  final service = ref.read(keyboardShortcutServiceProvider);
  return ShortcutNotifier(service);
});

final shortcutExecutorProvider = Provider<ShortcutExecutor>((ref) {
  return ShortcutExecutor(navigator: ref.read(appNavigatorProvider));
});
