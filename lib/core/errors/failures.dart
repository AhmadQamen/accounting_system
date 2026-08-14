abstract class Failure {
  final String message;
  final int? statusCode;
  const Failure({required this.message, this.statusCode});
  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = '', super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'لا يوجد اتصال بالإنترنت'})
    : super(statusCode: null);
}

class ValidationFailure extends Failure {
  final dynamic errors;
  const ValidationFailure(this.errors, {super.message = '', super.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure({super.message = '', super.statusCode});
}

class AppFailure extends Failure {
  const AppFailure({super.message = '', super.statusCode});
}
