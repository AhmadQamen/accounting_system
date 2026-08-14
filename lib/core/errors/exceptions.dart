class AppException implements Exception {
  final String message;
  final int statusCode;
  AppException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ServerException extends AppException {
  ServerException(String message) : super(message, 500);
}

class UnauthorizedException extends AppException {
  UnauthorizedException(String message) : super(message, 401);
}

class SubscriptionRequiredException extends AppException {
  SubscriptionRequiredException(String message) : super(message, 402);
}

class PermissionException extends AppException {
  PermissionException(String message) : super(message, 403);
}

class ForceUpdateException extends AppException {
  final String? updateType;
  final String? latestVersionName;
  final int? latestVersionCode;
  final String? downloadUrl;

  ForceUpdateException(
    String message, {
    this.updateType,
    this.latestVersionName,
    this.latestVersionCode,
    this.downloadUrl,
  }) : super(message, 403);
}

class NotFoundException extends AppException {
  NotFoundException(String message) : super(message, 404);
}

class ValidationException extends AppException {
  final dynamic errors;
  ValidationException(String message, this.errors) : super(message, 400);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
  @override
  String toString() => message;
}
