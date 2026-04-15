class AppException implements Exception {
  final String message;
  final int statusCode;

  const AppException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class BadRequestException extends AppException {
  const BadRequestException(String message) : super(message, 400);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(String message) : super(message, 401);
}

class NotFoundException extends AppException {
  const NotFoundException(String message) : super(message, 404);
}

class ValidationException extends AppException {
  final dynamic errors;

  const ValidationException(String message, this.errors) : super(message, 422);
}

class ServerException extends AppException {
  const ServerException(String message) : super(message, 500);
}

class NetworkException extends AppException {
  const NetworkException(String message) : super(message, 0);
}

class RateLimitException extends AppException {
  final int retryAfterSeconds;
  RateLimitException(String message, {this.retryAfterSeconds = 60})
      : super(message, 429);
}
