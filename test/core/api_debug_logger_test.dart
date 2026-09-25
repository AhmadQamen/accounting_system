import 'package:accounting_system/core/network/api_debug_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts secrets in URLs and nested response bodies', () {
    final uri = redactApiUri(
      Uri.parse(
        'https://example.test/api/items?page=2&access_token=secret'
        '&X-Amz-Signature=signed',
      ),
    );
    final body =
        redactApiValue({
              'accessToken': 'access-secret',
              'profile': {'name': 'User', 'refresh_token': 'refresh-secret'},
              'items': [
                {'password': 'password-secret', 'id': 1},
              ],
            })
            as Map<String, Object?>;

    expect(uri.toString(), isNot(contains('secret')));
    expect(uri.queryParameters['page'], '2');
    expect(body.toString(), isNot(contains('access-secret')));
    expect(body.toString(), isNot(contains('refresh-secret')));
    expect(body.toString(), isNot(contains('password-secret')));
    expect(body.toString(), contains('User'));
    final error = redactApiErrorText(
      'Bearer bearer-secret access_token=query-secret password=pass-secret',
    );
    expect(error, isNot(contains('bearer-secret')));
    expect(error, isNot(contains('query-secret')));
    expect(error, isNot(contains('pass-secret')));
  });

  test('debug interceptor preserves success and all Dio error paths', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    addTearDown(dio.close);
    dio.interceptors.add(createApiDebugLogInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          switch (options.path) {
            case '/success':
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'accessToken': 'must-not-leak', 'ok': true},
                ),
              );
            case '/client-error':
              handler.reject(_httpError(options, 401));
            case '/server-error':
              handler.reject(_httpError(options, 500));
            default:
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                  message: 'timeout',
                ),
              );
          }
        },
      ),
    );

    final success = await dio.get<Map<String, dynamic>>('/success');
    expect(success.statusCode, 200);
    expect(success.data?['ok'], isTrue);
    await expectLater(
      dio.get<void>('/client-error'),
      throwsA(_dioWithStatus(401)),
    );
    await expectLater(
      dio.get<void>('/server-error'),
      throwsA(_dioWithStatus(500)),
    );
    await expectLater(
      dio.get<void>('/network-error'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.connectionTimeout,
        ),
      ),
    );
  });
}

DioException _httpError(RequestOptions options, int status) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: options,
    statusCode: status,
    data: {'refreshToken': 'must-not-leak', 'message': 'failure'},
  ),
);

Matcher _dioWithStatus(int status) => isA<DioException>().having(
  (error) => error.response?.statusCode,
  'statusCode',
  status,
);
