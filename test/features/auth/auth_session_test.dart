import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/data/auth_repository.dart';
import 'package:accounting_system/features/auth/data/auth_session_manager.dart';
import 'package:accounting_system/features/auth/data/token_storage.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:accounting_system/features/auth/domain/models/organization_activation.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session refresh', () {
    test('concurrent 401 responses use one refresh and retry once', () async {
      final storage = MemoryTokenStorage(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/v1'));
      addTearDown(dio.close);
      var refreshRequests = 0;
      var protectedRequests = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/auth/refresh') {
              refreshRequests++;
              await Future<void>.delayed(const Duration(milliseconds: 20));
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-access',
                    'refreshToken': 'new-refresh',
                  },
                ),
              );
              return;
            }
            protectedRequests++;
            if (options.headers['Authorization'] == 'Bearer new-access') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'ok': true},
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'message': 'expired'},
                  ),
                ),
              );
            }
          },
        ),
      );

      final session = AuthSessionManager(dio: dio, tokenStorage: storage);
      final client = ApiClient(
        dio: dio,
        getAccessToken: session.readAccessToken,
        refreshSession: session.refreshSession,
        onSessionExpired: session.expireSession,
      );

      final results = await Future.wait([
        client.get<bool>(
          url: '/protected',
          parseResponse: (d) => d['ok'] as bool,
        ),
        client.get<bool>(
          url: '/protected',
          parseResponse: (d) => d['ok'] as bool,
        ),
      ]);

      expect(results, everyElement(isTrue));
      expect(refreshRequests, 1);
      expect(protectedRequests, 4);
      expect(storage.value?.accessToken, 'new-access');
      expect(storage.value?.refreshToken, 'new-refresh');
      expect(storage.writeCount, 1);
    });

    test('failed refresh clears the session and reports expiration', () async {
      final storage = MemoryTokenStorage(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/v1'));
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'message': 'expired'},
                ),
              ),
            );
          },
        ),
      );
      final session = AuthSessionManager(dio: dio, tokenStorage: storage);
      var expirationNotifications = 0;
      session.addExpiredListener(() => expirationNotifications++);
      final client = ApiClient(
        dio: dio,
        getAccessToken: session.readAccessToken,
        refreshSession: session.refreshSession,
        onSessionExpired: session.expireSession,
      );

      await expectLater(
        client.get<void>(url: '/protected', parseResponse: (_) {}),
        throwsA(isA<Exception>()),
      );
      expect(storage.value, isNull);
      expect(expirationNotifications, 1);
    });
  });

  group('membership selection', () {
    test('does not silently choose among multiple memberships', () async {
      final user = AuthUser(
        id: 'user-1',
        name: 'User',
        email: 'user@example.com',
        memberships: const [
          Membership(
            membershipId: 'membership-1',
            entityId: 'entity-1',
            entityName: 'First',
            currencyCode: 'USD',
            timezone: 'UTC',
            role: 'OWNER',
          ),
          Membership(
            membershipId: 'membership-2',
            entityId: 'entity-2',
            entityName: 'Second',
            currencyCode: 'EUR',
            timezone: 'UTC',
            role: 'ACCOUNTANT',
          ),
        ],
      );
      final storage = MemoryTokenStorage();
      final dio = Dio();
      addTearDown(dio.close);
      final session = AuthSessionManager(dio: dio, tokenStorage: storage);
      final notifier = AuthNotifier(
        repository: FakeAuthRepository(loginUser: user),
        sessionManager: session,
        organizationActivator: FakeOrganizationActivator(),
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      await notifier.login(email: user.email, password: 'not-recorded');

      expect(notifier.status, AuthStatus.choosingMembership);
      expect(notifier.selectedMembership, isNull);
      await notifier.selectMembership(user.memberships.last);
      expect(notifier.status, AuthStatus.authenticated);
      expect(notifier.selectedMembership?.entityId, 'entity-2');

      notifier.chooseAnotherMembership();
      expect(notifier.status, AuthStatus.choosingMembership);
      expect(notifier.selectedMembership, isNull);
    });

    test(
      'revoked registration does not authenticate the organization',
      () async {
        const membership = Membership(
          membershipId: 'membership-revoked',
          entityId: 'entity-revoked',
          entityName: 'Revoked',
          currencyCode: 'USD',
          timezone: 'UTC',
          role: 'VIEWER',
        );
        const user = AuthUser(
          id: 'user-1',
          name: 'User',
          email: 'user@example.com',
          memberships: [membership],
        );
        final dio = Dio();
        addTearDown(dio.close);
        final notifier = AuthNotifier(
          repository: FakeAuthRepository(loginUser: user),
          sessionManager: AuthSessionManager(
            dio: dio,
            tokenStorage: MemoryTokenStorage(),
          ),
          organizationActivator: FakeOrganizationActivator(revoked: true),
        );
        addTearDown(notifier.dispose);

        await notifier.login(email: user.email, password: 'not-recorded');

        expect(notifier.status, AuthStatus.deviceRevoked);
        expect(notifier.isAuthenticated, isFalse);
        expect(notifier.errorMessage, contains('ألغت الإدارة'));
      },
    );
  });
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.value]);

  AuthTokens? value;
  int writeCount = 0;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async {
    writeCount++;
    value = tokens;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.loginUser, this.restoredUser});

  final AuthUser loginUser;
  final AuthUser? restoredUser;

  @override
  Future<AuthUser> fetchCurrentUser() async => loginUser;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => loginUser;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> restoreSession() async => restoredUser;
}

class FakeOrganizationActivator implements OrganizationActivator {
  FakeOrganizationActivator({this.revoked = false});

  final bool revoked;

  @override
  Future<OrganizationActivationResult> activate({
    required AuthUser user,
    required Membership membership,
  }) async {
    return OrganizationActivationResult(
      deviceId: 'device-test',
      revoked: revoked,
    );
  }
}
