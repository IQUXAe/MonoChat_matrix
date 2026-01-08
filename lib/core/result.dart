import 'exceptions/app_exception.dart';

/// A Result type for explicit error handling.
///
/// Provides a functional approach to error handling that forces callers
/// to handle both success and failure cases explicitly.
///
/// Example:
/// ```dart
/// final result = await authRepository.login(...);
/// result.fold(
///   (user) => print('Logged in as $user'),
///   (error) => showError(error.userMessage),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// Returns true if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Returns the value if [Success], otherwise null.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// Returns the exception if [Failure], otherwise null.
  AppException? get exceptionOrNull => switch (this) {
    Success() => null,
    Failure(:final exception) => exception,
  };

  /// Pattern matches on [Success] or [Failure] and returns a value.
  R fold<R>(
    R Function(T value) onSuccess,
    R Function(AppException exception) onFailure,
  ) {
    return switch (this) {
      Success(:final value) => onSuccess(value),
      Failure(:final exception) => onFailure(exception),
    };
  }

  /// Maps the success value to a new type.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Failure(:final exception) => Failure(exception),
    };
  }

  /// Chains another Result-returning operation.
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    return switch (this) {
      Success(:final value) => await transform(value),
      Failure(:final exception) => Failure(exception),
    };
  }

  /// Returns the value or throws the exception.
  T getOrThrow() {
    return switch (this) {
      Success(:final value) => value,
      Failure(:final exception) => throw exception,
    };
  }

  /// Returns the value or a default.
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(:final value) => value,
      Failure() => defaultValue,
    };
  }
}

/// Represents a successful result containing a [value].
final class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result containing an [exception].
final class Failure<T> extends Result<T> {
  final AppException exception;

  const Failure(this.exception);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          exception == other.exception;

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'Failure($exception)';
}
