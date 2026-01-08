import 'package:matrix/matrix.dart' hide Result;

import '../../core/result.dart';

/// Abstract repository for authentication operations.
///
/// This abstraction allows for testing and alternative implementations
/// without depending on specific Matrix SDK details.
abstract class AuthRepository {
  /// The current Matrix client instance.
  Client? get client;

  /// Stream of login state changes.
  Stream<LoginState> get loginStateStream;

  /// Returns true if the user is currently logged in.
  bool get isLoggedIn;

  /// Initializes the Matrix client and restores any existing session.
  ///
  /// Returns [Success] with void if initialization succeeds,
  /// or [Failure] with an [AppException] if it fails.
  Future<Result<void>> initialize();

  /// Logs in with the provided credentials.
  ///
  /// The [homeserver] should be a valid Matrix homeserver URL.
  /// If no protocol is provided, HTTPS will be assumed.
  ///
  /// Returns [Success] if login succeeds, or [Failure] with
  /// an [AuthException] (e.g., [InvalidCredentialsException]) if it fails.
  Future<Result<void>> login({
    required String username,
    required String password,
    required String homeserver,
  });

  /// Logs out and clears the current session.
  Future<Result<void>> logout();
}
