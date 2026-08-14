import 'dart:io';
import 'exceptions.dart';
import 'failures.dart';

Failure mapExceptionToFailure(Exception exception) {
  if (exception is ValidationException) {
    return ValidationFailure(
      exception.errors,
      message: exception.message,
      statusCode: exception.statusCode,
    );
  }
  if (exception is UnauthorizedException) {
    return AuthFailure(message: exception.message, statusCode: 401);
  }
  if (exception is SubscriptionRequiredException) {
    return ServerFailure(message: exception.message, statusCode: 402);
  }
  if (exception is PermissionException) {
    return AuthFailure(message: exception.message, statusCode: 403);
  }
  if (exception is NotFoundException) {
    return ServerFailure(message: exception.message, statusCode: 404);
  }
  if (exception is ServerException) {
    return ServerFailure(message: exception.message, statusCode: exception.statusCode);
  }
  if (exception is NetworkException) {
    return NetworkFailure(message: exception.message);
  }
  if (exception is SocketException) {
    return const NetworkFailure();
  }
  if (exception is HttpException) {
    return const NetworkFailure();
  }

  return const ServerFailure(message: 'حدث خطأ غير متوقع');
}
