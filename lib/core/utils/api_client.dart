import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:dio/dio.dart';

enum RefreshOutcome { refreshed, expired, networkError }

class ApiClient {
  final Dio dio;
  final String language;

  final Future<String?> Function()? getAccessToken;
  final Future<RefreshOutcome> Function()? refreshSession;
  final void Function()? onSessionExpired;

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
    log(url);
    final response = await _execute(
      () => dio.get(
        url,
        queryParameters: queryParams,
        options: _buildOptions(token, timeout),
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
    log(url);
    log(body.toString());

    final response = await _execute(
      () => dio.post(url, data: body, options: _buildOptions(token, timeout)),
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
    log(url);
    log(body.toString());
    final response = await _execute(
      () => dio.put(url, data: body, options: _buildOptions(token, timeout)),
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
    log(url);
    log(body.toString());
    final response = await _execute(
      () => dio.patch(url, data: body, options: _buildOptions(token, timeout)),
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
    log(url);
    log(body.toString());
    final response = await _execute(
      () => dio.delete(url, data: body, options: _buildOptions(token, timeout)),
      token: token,
    );
    return parseResponse(response.data ?? {});
  }

  Options _buildOptions(String? token, Duration? timeout) {
    return Options(
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': language,
        if (token != null) 'Authorization': 'Bearer $token',
      },
      sendTimeout: timeout ?? const Duration(seconds: kTimeout),
      receiveTimeout: timeout ?? const Duration(seconds: kTimeout),
    );
  }

  Future<Response> _execute(
    Future<Response> Function() request, {
    String? token,
  }) async {
    try {
      final response = await request();
      log(
        'Response status: ${response.statusCode} data: ${jsonEncode(response.data)}',
      );
      _validateStatusCode(response);
      return response;
    } on DioException catch (e) {
      log('DioException: ${e.message} response: ${e.response?.data}');

      // ForceUpdateException thrown by interceptor
      if (e.error is ForceUpdateException) {
        throw e.error as ForceUpdateException;
      }

      if (e.response != null) {
        final response = e.response!;
        final statusCode = response.statusCode ?? 0;

        if (statusCode == 401) {
          if (refreshSession == null) throw _mapToException(response);
          final outcome = await _refreshTokenSingleFlight();
          switch (outcome) {
            case RefreshOutcome.refreshed:
              final newToken = await getAccessToken?.call();
              return await _execute(request, token: newToken);
            case RefreshOutcome.expired:
              onSessionExpired?.call();
              throw _mapToException(response);
            case RefreshOutcome.networkError:
              throw const NetworkException('حدثت مشكلة في الاتصال');
          }
        }

        throw _mapToException(response);
      }

      if (e.error is SocketException ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('لا يوجد اتصال بالإنترنت');
      }

      throw const NetworkException('حدثت مشكلة في الاتصال');
    }
  }

  String _extractMessage(dynamic data) {
    if (data is! Map) return 'Request failed';
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
