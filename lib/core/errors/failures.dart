abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  String toString() => message;
}

// Server Failures
class ServerFailure extends Failure {
  const ServerFailure({super.message = "", super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = ""});
}

class AppFailure extends Failure {
  const AppFailure({super.message = ""});
}

// Network Failures
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

// Authentication Failures
class AuthFailure extends Failure {
  const AuthFailure({super.message = "", super.statusCode});
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password',
    super.statusCode = 401,
  });
}

// Validation Failures
class ValidationFailure extends Failure {
  final dynamic errors;

  const ValidationFailure(this.errors, {super.message = "", super.statusCode});

  String get formattedErrors =>
      errors.entries.map((e) => '${e.key}: ${e.value}').join('\n');
}

// Business Rule Failures
class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure({super.message = ""});
}
