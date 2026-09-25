import 'package:accounting_system/core/configs/api_config.dart';
import 'package:dio/dio.dart';

/// The only place where the application's [Dio] instance is configured.
Dio createAppDio({String? baseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.normalizeBaseUrl(baseUrl ?? ApiConfig.baseUrl),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      },
    ),
  );
}
