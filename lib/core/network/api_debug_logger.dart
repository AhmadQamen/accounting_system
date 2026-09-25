import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const ansiReset = '\x1B[0m';
const ansiRed = '\x1B[31m';
const ansiGreen = '\x1B[32m';
const ansiYellow = '\x1B[33m';
const ansiCyan = '\x1B[36m';

const _redacted = '<redacted>';

Interceptor createApiDebugLogInterceptor() => InterceptorsWrapper(
  onResponse: (response, handler) {
    if (kDebugMode) {
      _safeWrite(
        method: response.requestOptions.method,
        uri: response.realUri,
        statusCode: response.statusCode,
        responseBody: response.data,
      );
    }
    handler.next(response);
  },
  onError: (error, handler) {
    if (kDebugMode) {
      final response = error.response;
      _safeWrite(
        method: error.requestOptions.method,
        uri: response?.realUri ?? error.requestOptions.uri,
        statusCode: response?.statusCode,
        responseBody: response?.data,
        error: redactApiErrorText(
          '${error.type}: ${error.message ?? ''}'.trim(),
        ),
      );
    }
    handler.next(error);
  },
);

void _safeWrite({
  required String method,
  required Uri uri,
  required int? statusCode,
  required Object? responseBody,
  String? error,
}) {
  // Logging must never affect the request result.
  try {
    writeApiLog(
      method: method,
      safeUrl: redactApiUri(uri).toString(),
      statusCode: statusCode,
      safeResponseBody: redactApiValue(responseBody),
      safeError: error,
    );
  } catch (_) {}
}

@visibleForTesting
Uri redactApiUri(Uri uri) {
  if (uri.queryParametersAll.isEmpty) return uri;
  final safeQuery = <String, List<String>>{};
  for (final entry in uri.queryParametersAll.entries) {
    safeQuery[entry.key] =
        _isSensitiveKey(entry.key) ? const [_redacted] : entry.value;
  }
  return uri.replace(queryParameters: safeQuery);
}

@visibleForTesting
Object? redactApiValue(Object? value, {String? key}) {
  if (key != null && _isSensitiveKey(key)) return _redacted;
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): redactApiValue(
          entry.value,
          key: entry.key.toString(),
        ),
    };
  }
  if (value is Iterable && value is! String) {
    return value.map((item) => redactApiValue(item)).toList(growable: false);
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return redactApiValue(decoded);
    } catch (_) {
      return value.length > 4096
          ? '${value.substring(0, 4096)}… <truncated>'
          : value;
    }
  }
  if (value is Uint8List || value is Stream) {
    return '<binary/stream response omitted>';
  }
  return value;
}

@visibleForTesting
String redactApiErrorText(String value) {
  var safe = value.replaceAll(
    RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
    'Bearer $_redacted',
  );
  safe = safe.replaceAllMapped(
    RegExp(
      r'(access[_-]?token|refresh[_-]?token|token|password|signature|secret)'
      r'(["\x27]?\s*[:=]\s*["\x27]?)([^&\s,"\x27}\]]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)}$_redacted',
  );
  return safe;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized.contains('accesstoken') ||
      normalized.contains('refreshtoken') ||
      normalized == 'token' ||
      normalized.contains('password') ||
      normalized.contains('authorization') ||
      normalized.contains('signature') ||
      normalized.contains('secret');
}

String encodeForApiLog(Object? data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return data.toString();
  }
}

void writeApiLog({
  required String method,
  required String safeUrl,
  required int? statusCode,
  required Object? safeResponseBody,
  String? safeError,
}) {
  if (!kDebugMode) return;

  final success = statusCode != null && statusCode >= 200 && statusCode < 300;
  final clientError =
      statusCode != null && statusCode >= 400 && statusCode < 500;
  final serverOrNetworkError = statusCode == null || statusCode >= 500;
  final color =
      success
          ? ansiGreen
          : serverOrNetworkError
          ? ansiRed
          : ansiYellow;
  final label =
      success
          ? '🟢 [API SUCCESS]'
          : clientError
          ? '🟡 [API CLIENT ERROR]'
          : serverOrNetworkError
          ? '🔴 [API ERROR]'
          : '🟡 [API RESPONSE]';

  developer.log(
    '$color$label$ansiReset ${method.toUpperCase()} '
    '$ansiCyan$safeUrl$ansiReset\n'
    '${color}status: ${statusCode ?? 'no response'}\n'
    'response: ${encodeForApiLog(safeResponseBody)}'
    '${safeError == null ? '' : '\nerror: $safeError'}'
    '$ansiReset',
    name: 'ApiClient',
  );
}
