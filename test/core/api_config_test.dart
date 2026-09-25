import 'package:accounting_system/core/configs/api_config.dart';
import 'package:accounting_system/core/network/dio_factory.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig', () {
    test('uses the production API v1 endpoint by default', () {
      expect(
        ApiConfig.baseUrl,
        'https://accounting.alkhaleel-mosque.com/api/v1',
      );
    });

    test('removes trailing slashes and duplicate api version suffixes', () {
      expect(
        ApiConfig.normalizeBaseUrl(
          'https://accounting.alkhaleel-mosque.com/api/v1/api/v1///',
        ),
        'https://accounting.alkhaleel-mosque.com/api/v1',
      );
    });

    test('rejects insecure remote, legacy, and admin endpoints', () {
      expect(
        () => ApiConfig.normalizeBaseUrl('http://example.com/api/v1'),
        throwsFormatException,
      );
      expect(
        () => ApiConfig.normalizeBaseUrl('https://192.0.2.10/api/v1'),
        throwsFormatException,
      );
      expect(
        () => ApiConfig.normalizeBaseUrl(
          'https://accounting.alkhaleel-mosque.com/admin/api/v1',
        ),
        throwsFormatException,
      );
    });

    test('allows local HTTP development only', () {
      expect(
        ApiConfig.normalizeBaseUrl('http://localhost:8080/api/v1/'),
        'http://localhost:8080/api/v1',
      );
    });

    test('normalizes relative request paths without repeating api version', () {
      expect(ApiConfig.requestPath('auth/login'), '/auth/login');
      expect(ApiConfig.requestPath('/api/v1/sync/pull'), '/sync/pull');
      expect(
        () => ApiConfig.requestPath(
          'https://accounting.alkhaleel-mosque.com/api/v1/me',
        ),
        throwsFormatException,
      );
      expect(
        () => ApiConfig.requestPath('/admin/users'),
        throwsFormatException,
      );
    });
  });

  test('Dio is created from the central configuration', () {
    final dio = createAppDio();
    addTearDown(dio.close);

    expect(dio.options.baseUrl, ApiConfig.productionBaseUrl);
    expect(dio.options.connectTimeout, const Duration(seconds: 15));
    expect(dio.options.sendTimeout, const Duration(seconds: 30));
    expect(dio.options.receiveTimeout, const Duration(seconds: 30));
    expect(dio.options.headers[Headers.acceptHeader], Headers.jsonContentType);
    expect(
      dio.options.headers[Headers.contentTypeHeader],
      Headers.jsonContentType,
    );
  });
}
