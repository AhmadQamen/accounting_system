import 'dart:async';

import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/network/session_refresh.dart';
import 'package:accounting_system/features/auth/data/token_storage.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:dio/dio.dart';

typedef SessionExpiredListener = void Function();

class AuthSessionManager {
  AuthSessionManager({required Dio dio, required TokenStorage tokenStorage})
    : _dio = dio,
      _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Set<SessionExpiredListener> _expiredListeners = {};
  bool _isExpired = false;

  Future<AuthTokens?> readTokens() => _tokenStorage.read();

  Future<String?> readAccessToken() async =>
      (await _tokenStorage.read())?.accessToken;

  Future<void> saveTokens(AuthTokens tokens) async {
    await _tokenStorage.write(tokens);
    _isExpired = false;
  }

  Future<void> clearSession({bool notify = false}) async {
    await _tokenStorage.clear();
    if (!notify || _isExpired) return;
    _isExpired = true;
    for (final listener in List<SessionExpiredListener>.of(_expiredListeners)) {
      listener();
    }
  }

  Future<void> expireSession() => clearSession(notify: true);

  void addExpiredListener(SessionExpiredListener listener) =>
      _expiredListeners.add(listener);

  void removeExpiredListener(SessionExpiredListener listener) =>
      _expiredListeners.remove(listener);

  Future<RefreshOutcome> refreshSession() async {
    final current = await _tokenStorage.read();
    if (current == null) {
      await expireSession();
      return RefreshOutcome.expired;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': current.refreshToken},
      );
      final data = response.data;
      if (data == null) {
        await expireSession();
        return RefreshOutcome.expired;
      }
      final rotatedTokens = AuthTokens.fromJson(data);
      await saveTokens(rotatedTokens);
      return RefreshOutcome.refreshed;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == null || status >= 500) return RefreshOutcome.networkError;
      await expireSession();
      return RefreshOutcome.expired;
    } on FormatException {
      await expireSession();
      return RefreshOutcome.expired;
    }
  }
}
