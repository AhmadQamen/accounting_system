import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String event, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    debugPrint('[INFO] $event${_fields(fields)}');
  }

  static void warning(String event, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    debugPrint('[WARN] $event${_fields(fields)}');
  }

  static String _fields(Map<String, Object?> fields) {
    if (fields.isEmpty) return '';
    return ' ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  }
}
