import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

import '../core/exceptions/app_exception.dart';
import '../domain/repositories/auth_repository.dart';
import '../services/cache/secure_cache_service.dart';

// =============================================================================
// AUTH STATE
// =============================================================================

/// Represents the authentication state of the app.
enum AuthState {
  /// Initial state while checking for existing session.
  initializing,

  /// No valid session found.
  unauthenticated,

  /// User is logged in.
  authenticated,

  /// An error occurred during initialization.
  error,

  /// Secure storage is unavailable, preventing safe execution.
  secureStorageFailure,
}

// =============================================================================
// AUTH CONTROLLER
// =============================================================================

/// Controller for authentication state and operations.
///
/// Manages user authentication lifecycle:
/// - Session initialization and restoration
/// - Login/logout operations
/// - Authentication state changes
///
/// Uses [AuthRepository] abstraction for better testability
/// and separation from Matrix SDK implementation details.
class AuthController extends ChangeNotifier {
  // ===========================================================================
  // DEPENDENCIES
  // ===========================================================================

  final AuthRepository _authRepository;
  static final Logger _log = Logger('AuthController');

  // ===========================================================================
  // STATE
  // ===========================================================================

  AuthState _state = AuthState.initializing;
  AuthState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The Matrix client, if initialized.
  Client? get client => _authRepository.client;

  // ===========================================================================
  // INTERNAL
  // ===========================================================================

  StreamSubscription<LoginState>? _loginStateSubscription;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  AuthController(this._authRepository) {
    _init();
  }

  Future<void> _init() async {
    _state = AuthState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      _log.info('Starting Matrix initialization...');

      final result = await _authRepository.initialize();
      result.fold((_) {
        // Success - continue with setup
      }, (exception) => throw exception);

      // Listen for login state changes
      _loginStateSubscription?.cancel();
      _loginStateSubscription = _authRepository.loginStateStream.listen((
        loginState,
      ) async {
        _log.info('Login state change detected: $loginState');
        if (loginState == LoginState.loggedIn) {
          _state = AuthState.authenticated;
        } else if (loginState == LoginState.loggedOut) {
          _state = AuthState.unauthenticated;
          await SecureCacheService().nuke();
        }
        notifyListeners();
      });

      if (_authRepository.isLoggedIn) {
        _log.info('Session found.');
        _state = AuthState.authenticated;
      } else {
        _log.info('No session found.');
        _state = AuthState.unauthenticated;
      }
    } catch (e, s) {
      if (e.toString().contains('Secure Storage')) {
        _state = AuthState.secureStorageFailure;
        _errorMessage = e.toString();
        _log.severe('Secure Storage Error', e, s);
      } else {
        _state = AuthState.error;
        _errorMessage = e is AppException ? e.userMessage : e.toString();
        _log.severe('Init Error', e, s);
      }
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _loginStateSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Retries initialization after an error.
  Future<void> retry() async {
    await _init();
  }

  /// Logs in with the provided credentials.
  ///
  /// Throws the error message on failure for UI handling.
  Future<void> login(
    String username,
    String password,
    String homeserver,
  ) async {
    final result = await _authRepository.login(
      username: username,
      password: password,
      homeserver: homeserver,
    );

    result.fold((_) => _log.info('Login successful'), (exception) {
      _log.warning('Login Error', exception);
      throw exception; // Propagate the full exception for better UI handling
    });
  }

  /// Logs out the current user.
  Future<void> logout() async {
    final result = await _authRepository.logout();
    result.fold(
      (_) => _log.info('Logout successful'),
      (e) => _log.warning('Logout error: ${e.message}'),
    );
  }

  /// Called when user logs in via SSO or other external method.
  /// Updates the auth state to authenticated.
  void notifyLoggedIn() {
    if (_authRepository.isLoggedIn) {
      _state = AuthState.authenticated;
      notifyListeners();
    }
  }
}
