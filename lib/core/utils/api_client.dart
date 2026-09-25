import 'dart:async';
import 'dart:io';

import 'package:accounting_system/core/configs/api_config.dart';
import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:accounting_system/core/network/session_refresh.dart';
import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;
  final String language;

  final Future<String?> Function()? getAccessToken;
  final Future<RefreshOutcome> Function()? refreshSession;
  final FutureOr<void> Function()? onSessionExpired;

  static const int kTimeout = 15;

  Completer<RefreshOutcome>? _refreshInFlight;

  ApiClient({
    required this.dio,
    this.language = 'ar',
    this.getAccessToken,
    this.refreshSession,
    this.onSessionExpired,
  });

  Future<T> get<T>({
    required String url,
    required T Function(dynamic data) parseResponse,
    Map<String, dynamic>? queryParams,
    String? token,
    Duration? timeout,
  }) async {
    final path = ApiConfig.requestPath(url);
    final response = await _execute(
      (accessToken) => dio.get(
        path,
        queryParameters: queryParams,
        options: _buildOptions(accessToken, timeout),
      ),
      token: token,
    );
    return parseResponse(response.data ?? {});
  }

  Future<T> post<T>({
    required String url,
    dynamic body,
    required T Function(dynamic data) parseResponse,
    String? token,
    Duration? timeout,
  }) async {
    final path = ApiConfig.requestPath(url);

    final response = await _execute(
      (accessToken) => dio.post(
        path,
        data: body,
        options: _buildOptions(accessToken, timeout),
      ),
      token: token,
    );
    final raw = response.data;

    return parseResponse(raw ?? {});
  }

  Future<T> put<T>({
    required String url,
    dynamic body,
    required T Function(dynamic data) parseResponse,
    String? token,
    Duration? timeout,
  }) async {
    final path = ApiConfig.requestPath(url);
    final response = await _execute(
      (accessToken) => dio.put(
        path,
        data: body,
        options: _buildOptions(accessToken, timeout),
      ),
      token: token,
    );
    return parseResponse(response.data ?? {});
  }

  Future<T> patch<T>({
    required String url,
    dynamic body,
    required T Function(dynamic data) parseResponse,
    String? token,
    Duration? timeout,
  }) async {
    final path = ApiConfig.requestPath(url);
    final response = await _execute(
      (accessToken) => dio.patch(
        path,
        data: body,
        options: _buildOptions(accessToken, timeout),
      ),
      token: token,
    );
    return parseResponse(response.data ?? {});
  }

  Future<T> delete<T>({
    required String url,
    dynamic body,
    required T Function(dynamic data) parseResponse,
    String? token,
    Duration? timeout,
  }) async {
    final path = ApiConfig.requestPath(url);
    final response = await _execute(
      (accessToken) => dio.delete(
        path,
        data: body,
        options: _buildOptions(accessToken, timeout),
      ),
      token: token,
    );
    return parseResponse(response.data ?? {});
  }

  Options _buildOptions(String? token, Duration? timeout) {
    return Options(
      headers: {
        'Accept-Language': language,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      sendTimeout: timeout ?? const Duration(seconds: kTimeout),
      receiveTimeout: timeout ?? const Duration(seconds: kTimeout),
    );
  }

  Future<Response> _execute(
    Future<Response> Function(String? accessToken) request, {
    String? token,
    bool allowRefresh = true,
  }) async {
    final resolvedToken = token ?? await getAccessToken?.call();
    try {
      final response = await request(resolvedToken);
      _validateStatusCode(response);
      return response;
    } on DioException catch (e) {
      // ForceUpdateException thrown by interceptor
      if (e.error is ForceUpdateException) {
        throw e.error as ForceUpdateException;
      }

      if (e.response != null) {
        final response = e.response!;
        final statusCode = response.statusCode ?? 0;

        if (statusCode == 401) {
          if (!allowRefresh || refreshSession == null) {
            if (!allowRefresh) await onSessionExpired?.call();
            throw _mapToException(response);
          }
          final outcome = await _refreshTokenSingleFlight();
          switch (outcome) {
            case RefreshOutcome.refreshed:
              final newToken = await getAccessToken?.call();
              return _execute(request, token: newToken, allowRefresh: false);
            case RefreshOutcome.expired:
              await onSessionExpired?.call();
              throw _mapToException(response);
            case RefreshOutcome.networkError:
              throw const NetworkException('حدثت مشكلة في الاتصال');
          }
        }

        throw _mapToException(response);
      }

      if (e.error is SocketException ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('لا يوجد اتصال بالإنترنت');
      }

      throw const NetworkException('حدثت مشكلة في الاتصال');
    }
  }

  String _extractMessage(dynamic data) {
    if (data is! Map) return 'Request failed';
    if (data['message'] != null) return data['message'].toString();
    if (data['detail'] != null) return data['detail'].toString();
    if (data['non_field_errors'] is List) {
      final errors = data['non_field_errors'] as List;
      return errors.isNotEmpty ? errors.first.toString() : 'Request failed';
    }
    // Handle field-level validation errors like {old_password: ["Current password is incorrect"]}
    for (final entry in data.entries) {
      if (entry.value is List && (entry.value as List).isNotEmpty) {
        return (entry.value as List).first.toString();
      }
    }
    return 'Request failed';
  }

  void _validateStatusCode(Response response) {
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) return;
    final data = response.data;
    final message = _extractMessage(data);

    switch (statusCode) {
      case 400:
        throw ValidationException(message, data is Map ? data : null);
      case 401:
        throw UnauthorizedException(message);
      case 402:
        throw SubscriptionRequiredException(message);
      case 403:
        throw PermissionException(message);
      case 404:
        throw NotFoundException(message);
      case 429:
        throw ServerException(message);
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException(message);
      default:
        throw ServerException(message);
    }
  }

  Exception _mapToException(Response response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    final message = _extractMessage(data);

    switch (statusCode) {
      case 400:
        return ValidationException(message, data is Map ? data : null);
      case 401:
        return UnauthorizedException(message);
      case 402:
        return SubscriptionRequiredException(message);
      case 403:
        return PermissionException(message);
      case 404:
        return NotFoundException(message);
      case 429:
        return ServerException(message);
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(message);
      default:
        return ServerException(message);
    }
  }

  Future<RefreshOutcome> _refreshTokenSingleFlight() {
    final inflight = _refreshInFlight;
    if (inflight != null) return inflight.future;

    final completer = Completer<RefreshOutcome>();
    _refreshInFlight = completer;
    () async {
      RefreshOutcome result;
      try {
        result = await refreshSession!();
      } catch (_) {
        result = RefreshOutcome.networkError;
      }
      _refreshInFlight = null;
      completer.complete(result);
    }();
    return completer.future;
  }
}
