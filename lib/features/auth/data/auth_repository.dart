import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/data/auth_session_manager.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:dio/dio.dart';

abstract interface class AuthRepository {
  Future<AuthUser> login({required String email, required String password});
  Future<AuthUser> fetchCurrentUser();
  Future<AuthUser?> restoreSession();
  Future<AuthUser?> restoreCachedSession();
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
  Future<AuthUser?> restoreCachedSession() async {
    if (await _sessionManager.readTokens() == null) return null;
    try {
      final context = await LocalContextService.instance.current;
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'users',
        columns: ['name', 'email'],
        where: 'id=? AND entity_id=?',
        whereArgs: [context.userId, context.entityId],
        limit: 1,
      );
      final localUser = rows.isEmpty ? const <String, Object?>{} : rows.first;
      return AuthUser(
        id: context.serverUserId,
        name: localUser['name']?.toString() ?? context.entityName,
        email: localUser['email']?.toString() ?? '',
        memberships: [
          Membership(
            membershipId: context.membershipId,
            entityId: context.entityId,
            entityName: context.entityName,
            currencyCode: context.currencyCode,
            timezone: context.timezone,
            role: context.role,
          ),
        ],
      );
    } on LocalContextUnavailableException {
      return null;
    }
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
