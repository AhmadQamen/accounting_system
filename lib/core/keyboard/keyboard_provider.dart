import 'package:accounting_system/core/shortcuts/shortcut_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'barcode_reader.dart';
import 'keyboard_manager.dart';

final keyboardManagerProvider = Provider<KeyboardManager>((ref) {
  return KeyboardManager(
    shortcuts: ref.read(shortcutNotifierProvider),
    executor: ref.read(shortcutExecutorProvider),
  );
});

final barcodeReaderProvider = Provider<BarcodeReader>((ref) {
  return ref.read(keyboardManagerProvider).barcodeReader;
});
