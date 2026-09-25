import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/data/auth_session_manager.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:dio/dio.dart';

abstract interface class AuthRepository {
  Future<AuthUser> login({required String email, required String password});
  Future<AuthUser> fetchCurrentUser();
  Future<AuthUser?> restoreSession();
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required Dio dio,
    required ApiClient apiClient,
    required AuthSessionManager sessionManager,
  }) : _dio = dio,
       _apiClient = apiClient,
       _sessionManager = sessionManager;

  final Dio _dio;
  final ApiClient _apiClient;
  final AuthSessionManager _sessionManager;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email.trim(), 'password': password},
    );
    final data = response.data;
    if (data == null) throw const FormatException('Invalid login response.');
    await _sessionManager.saveTokens(AuthTokens.fromJson(data));
    try {
      return await fetchCurrentUser();
    } catch (_) {
      await _sessionManager.clearSession();
      rethrow;
    }
  }

  @override
  Future<AuthUser> fetchCurrentUser() => _apiClient.get<AuthUser>(
    url: ApiEndpoints.me,
    parseResponse:
        (data) => AuthUser.fromJson(Map<String, dynamic>.from(data as Map)),
  );

  @override
  Future<AuthUser?> restoreSession() async {
    if (await _sessionManager.readTokens() == null) return null;
    return fetchCurrentUser();
  }

  @override
  Future<void> logout() async {
    final tokens = await _sessionManager.readTokens();
    try {
      if (tokens != null) {
        await _apiClient.post<void>(
          url: ApiEndpoints.logout,
          body: {'refreshToken': tokens.refreshToken},
          parseResponse: (_) {},
        );
      }
    } finally {
      await _sessionManager.clearSession();
    }
  }
}
