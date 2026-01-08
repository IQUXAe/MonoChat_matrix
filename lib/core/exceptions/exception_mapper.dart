import 'dart:io';

import 'package:matrix/matrix.dart';

import 'app_exception.dart';

/// Maps raw exceptions from Matrix SDK and system to typed [AppException]s.
class ExceptionMapper {
  ExceptionMapper._();

  /// Maps a raw exception to a typed [AppException].
  ///
  /// This centralizes error handling logic and provides consistent
  /// user-facing messages across the application.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    final errorStr = error.toString();

    // Network errors
    if (error is SocketException ||
        errorStr.contains('Network is unreachable') ||
        errorStr.contains('No address associated with hostname') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Connection timed out')) {
      return NetworkException(
        errorStr,
        debugInfo: errorStr,
        stackTrace: stackTrace,
      );
    }

    // Matrix SDK specific errors
    if (error is MatrixException) {
      return _mapMatrixException(error, stackTrace);
    }

    // String-based Matrix error matching (for cases where we get string errors)
    if (errorStr.contains('M_FORBIDDEN') ||
        errorStr.contains('Invalid password')) {
      return InvalidCredentialsException(debugInfo: errorStr);
    }

    if (errorStr.contains('M_UNKNOWN_TOKEN')) {
      return SessionExpiredException(debugInfo: errorStr);
    }

    if (errorStr.contains('M_NOT_FOUND')) {
      return RoomNotFoundException(debugInfo: errorStr);
    }

    // Fallback to generic exception
    return GenericException(
      errorStr,
      debugInfo: errorStr,
      stackTrace: stackTrace,
    );
  }

  /// Maps Matrix SDK specific exceptions
  static AppException _mapMatrixException(
    MatrixException error,
    StackTrace? stackTrace,
  ) {
    switch (error.errcode) {
      case 'M_FORBIDDEN':
        return InvalidCredentialsException(debugInfo: error.toString());

      case 'M_UNKNOWN_TOKEN':
        return SessionExpiredException(debugInfo: error.toString());

      case 'M_NOT_FOUND':
        return RoomNotFoundException(debugInfo: error.toString());

      case 'M_LIMIT_EXCEEDED':
        return const GenericException(
          'Rate limit exceeded. Please wait and try again.',
        );

      default:
        return GenericException(
          error.errorMessage,
          debugInfo: error.toString(),
          stackTrace: stackTrace,
        );
    }
  }
}
