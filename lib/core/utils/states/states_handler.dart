import 'dart:developer';

import 'package:accounting_system/core/errors/failures.dart';
import 'package:accounting_system/core/utils/handle_failures.dart';
import 'package:dartz/dartz.dart';

mixin StatesHandler {
  ProviderStates failureOrDataToState<T>(
    Either<Failure, T> either, {
    bool handleF = true,
    bool handleS = false,
  }) {
    return either.fold(
      (failure) {
        if (handleF) {
          handleFailure(failure);
        }
        log(failure.message);
        return ErrorState(failure: failure);
      },
      (data) {
        return DataState<T>(data: data);
      },
    );
  }
}

abstract class ProviderStates {
  const ProviderStates();
}

class ErrorState extends ProviderStates {
  final Failure failure;

  const ErrorState({required this.failure});
}

class DataState<T> extends ProviderStates {
  final T data;

  DataState({required this.data});
}
