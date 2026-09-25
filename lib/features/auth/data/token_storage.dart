import 'dart:convert';

import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'accounting.auth.tokens.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map) return null;
      return AuthTokens.fromJson(Map<String, dynamic>.from(json));
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: _sessionKey, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
