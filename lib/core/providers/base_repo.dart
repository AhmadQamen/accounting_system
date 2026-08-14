// import 'dart:ui';
// import 'package:dartz/dartz.dart';
// import '../errors/error_mapper.dart';
// import '../errors/failures.dart';
// import '../extensions/network_checker.dart';
// import '../../features/auth/data/datasourses/local/auth_local.dart';

// abstract class BaseRepository {
//   final NetworkInfo _networkInfo;
//   final AuthLocalDataSource _localDataSource;

//   BaseRepository(this._networkInfo, this._localDataSource);

//   static VoidCallback? onForceLogout;

//   Future<Either<Failure, T>> handleNetworkCall<T>({
//     required Future<T> Function(String token) remoteCall,
//     Function(Failure failure)? onFail,
//     Function(T result)? onSuccess,
//   }) async {
//     // Check internet connection
//     if (await _networkInfo.isConnected == false) {
//       const failure = NetworkFailure();
//       onFail?.call(failure);
//       return const Left(failure);
//     }

//     try {
//       // Get access token
//       final token = await _localDataSource.getAccessToken();

//       if (token == null || token.isEmpty) {
//         const failure = AuthFailure(message: 'Session expired');
//         onFail?.call(failure);
//         return const Left(failure);
//       }

//       // Execute remote request
//       final result = await remoteCall(token);

//       // Success callback
//       onSuccess?.call(result);

//       return Right(result);
//     } on Exception catch (e) {
//       final failure = mapExceptionToFailure(e);

//       // If unauthorized, force logout
//       if (failure is AuthFailure) {
//         onForceLogout?.call();
//       }

//       // Failure callback
//       onFail?.call(failure);

//       return Left(failure);
//     }
//   }

//   Future<Either<Failure, T>> handleLogin<T>({
//     required Future<T> Function() remoteCall,
//     Function(Failure failure)? onFail,
//     Function(T result)? onSuccess,
//   }) async {
//     if (await _networkInfo.isConnected == false) {
//       const failure = NetworkFailure();
//       onFail?.call(failure);
//       return const Left(failure);
//     }

//     try {
//       final result = await remoteCall();
//       onSuccess?.call(result);
//       return Right(result);
//     } on Exception catch (e) {
//       final failure = mapExceptionToFailure(e);
//       onFail?.call(failure);
//       return Left(failure);
//     }
//   }
// }
