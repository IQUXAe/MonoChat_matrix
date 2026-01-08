import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:logging/logging.dart';

import '../core/exceptions/app_exception.dart';
import '../domain/repositories/auth_repository.dart';

enum AuthState { initializing, unauthenticated, authenticated, error }

/// Controller for authentication state and operations.
///
/// Uses [AuthRepository] abstraction for better testability
/// and separation from Matrix SDK implementation details.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  static final Logger _log = Logger('AuthController');

  AuthState _state = AuthState.initializing;
  AuthState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Client? get client => _authRepository.client;

  StreamSubscription<LoginState>? _loginStateSubscription;

  AuthController(this._authRepository) {
    _init();
  }

  Future<void> _init() async {
    _state = AuthState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      _log.info("Starting Matrix initialization...");

      final result = await _authRepository.initialize();

      result.fold(
        (_) {
          // Success - continue with setup
        },
        (exception) {
          throw exception;
        },
      );

      // Listen for login state changes
      _loginStateSubscription?.cancel();
      _loginStateSubscription = _authRepository.loginStateStream.listen((
        loginState,
      ) {
        _log.info("Login state change detected: $loginState");
        if (loginState == LoginState.loggedIn) {
          _state = AuthState.authenticated;
        } else if (loginState == LoginState.loggedOut) {
          _state = AuthState.unauthenticated;
        }
        notifyListeners();
      });

      if (_authRepository.isLoggedIn) {
        _log.info("Session found.");
        _state = AuthState.authenticated;
      } else {
        _log.info("No session found.");
        _state = AuthState.unauthenticated;
      }
    } catch (e, s) {
      _state = AuthState.error;
      _errorMessage = e is AppException ? e.userMessage : e.toString();
      _log.severe("Init Error", e, s);
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _loginStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> retry() async {
    await _init();
  }

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

    result.fold(
      (_) {
        // Success - state updates via loginStateStream
        _log.info("Login successful");
      },
      (exception) {
        _log.warning("Login Error", exception);
        throw exception.userMessage;
      },
    );
  }

  Future<void> logout() async {
    final result = await _authRepository.logout();
    result.fold(
      (_) => _log.info("Logout successful"),
      (e) => _log.warning("Logout error: ${e.message}"),
    );
  }
}
