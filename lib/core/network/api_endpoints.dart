/// Relative paths from the official Accounting Sync API v1 contract.
///
/// These paths deliberately do not repeat `/api/v1`; that prefix belongs only
/// to [ApiConfig.baseUrl].
abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/me';

  static String registerDevice(String entityId) =>
      '/entities/${Uri.encodeComponent(entityId)}/devices/register';

  static String organizationMembers(String entityId) =>
      '/entities/${Uri.encodeComponent(entityId)}/members';

  static const syncBootstrap = '/sync/bootstrap';
  static const syncPush = '/sync/push';
  static const syncPull = '/sync/pull';
  static const syncAck = '/sync/ack';
  static const syncStatus = '/sync/status';
}
