/// Central API configuration for the Flutter application.
///
/// Override the production URL at build/run time with:
/// `--dart-define=API_BASE_URL=https://example.com/api/v1`.
abstract final class ApiConfig {
  static const productionBaseUrl =
      'https://accounting.alkhaleel-mosque.com/api/v1';

  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );

  /// Normalized URL with exactly one `/api/v1` suffix and no trailing slash.
  static final String baseUrl = normalizeBaseUrl(_configuredBaseUrl);

  static String normalizeBaseUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      throw const FormatException('API_BASE_URL cannot be empty.');
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw FormatException('API_BASE_URL is not a valid absolute URL: $raw');
    }
    if (parsed.hasQuery || parsed.hasFragment || parsed.userInfo.isNotEmpty) {
      throw const FormatException(
        'API_BASE_URL must not contain credentials, query parameters, or fragments.',
      );
    }
    final isLocalDevelopment =
        parsed.host == 'localhost' ||
        parsed.host == '127.0.0.1' ||
        parsed.host == '::1';
    final isIpAddress =
        RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$').hasMatch(parsed.host) ||
        parsed.host.contains(':');
    if (!isLocalDevelopment && (isIpAddress || parsed.hasPort)) {
      throw const FormatException(
        'Production API_BASE_URL must use a domain without a custom port.',
      );
    }
    if (parsed.scheme != 'https' &&
        !(parsed.scheme == 'http' && isLocalDevelopment)) {
      throw const FormatException(
        'API_BASE_URL must use HTTPS outside local development.',
      );
    }

    var path = parsed.path.replaceAll(RegExp('/+'), '/');
    path = path.replaceFirst(RegExp(r'/+$'), '');
    while (path.endsWith('/api/v1/api/v1')) {
      path = path.substring(0, path.length - '/api/v1'.length);
    }
    if (path.toLowerCase().contains('/admin')) {
      throw const FormatException('The admin dashboard is not a Flutter API.');
    }
    if (!path.endsWith('/api/v1')) {
      throw const FormatException('API_BASE_URL must end with /api/v1.');
    }

    return parsed.replace(path: path, query: null, fragment: null).toString();
  }

  /// Returns a relative Dio path with one leading slash and without `/api/v1`.
  ///
  /// This keeps callers from accidentally producing `/api/v1/api/v1/...` or
  /// bypassing the configured host with an absolute URL.
  static String requestPath(String value) {
    var path = value.trim();
    if (path.isEmpty) {
      throw const FormatException('API request path cannot be empty.');
    }
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      throw const FormatException(
        'Use relative API paths; absolute request URLs are not allowed.',
      );
    }

    path = path.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');
    path = path.startsWith('/') ? path : '/$path';
    if (path == '/api/v1') return '/';
    if (path.startsWith('/api/v1/')) {
      path = path.substring('/api/v1'.length);
    }
    if (path == '/admin' || path.startsWith('/admin/')) {
      throw const FormatException('The admin dashboard is not a Flutter API.');
    }
    return path;
  }
}
