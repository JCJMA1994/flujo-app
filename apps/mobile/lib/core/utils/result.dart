import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Alternativa ligera a `Either` de dartz, usando clases selladas de Dart 3.
/// Evita una dependencia externa y permite `switch` exhaustivo.
sealed class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        FailureResult<T>() => null,
      };

  R fold<R>({
    required R Function(Failure failure) onFailure,
    required R Function(T value) onSuccess,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        FailureResult<T>(:final failure) => onFailure(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success(transform(value)),
        FailureResult<T>(:final failure) => FailureResult<R>(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
