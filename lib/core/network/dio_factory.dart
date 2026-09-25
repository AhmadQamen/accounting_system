import 'package:accounting_system/core/configs/api_config.dart';
import 'package:accounting_system/core/network/api_debug_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// The only place where the application's [Dio] instance is configured.
Dio createAppDio({String? baseUrl}) {
  final dio = Dio(
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
  if (kDebugMode) {
    dio.interceptors.add(createApiDebugLogInterceptor());
  }
  return dio;
}
