import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart' hide Result;

import '../../core/exceptions/app_exception.dart';
import '../../core/exceptions/exception_mapper.dart';
import '../../core/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/matrix_service.dart';

/// Matrix SDK implementation of [AuthRepository].
class MatrixAuthRepository implements AuthRepository {
  final MatrixService _service;
  static final Logger _log = Logger('MatrixAuthRepository');

  MatrixAuthRepository(this._service);

  @override
  Client? get client => _service.client;

  @override
  Stream<LoginState> get loginStateStream =>
      _service.client?.onLoginStateChanged.stream ?? const Stream.empty();

  @override
  bool get isLoggedIn => _service.client?.isLogged() ?? false;

  @override
  Future<Result<void>> initialize() async {
    try {
      await _service.init();
      return const Success(null);
    } catch (e, s) {
      _log.severe('Initialization failed', e, s);
      return Failure(ExceptionMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> login({
    required String username,
    required String password,
    required String homeserver,
  }) async {
    try {
      var hs = homeserver;
      if (!hs.startsWith('http')) {
        hs = 'https://$hs';
      }

      final client = _service.client;
      if (client == null) {
        return const Failure(ClientNotInitializedException());
      }

      await client.checkHomeserver(Uri.parse(hs));
      await client.login(
        LoginType.mLoginPassword,
        password: password,
        identifier: AuthenticationUserIdentifier(user: username),
      );

      return const Success(null);
    } catch (e, s) {
      _log.warning('Login failed', e, s);
      return Failure(ExceptionMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _service.client?.logout();
      return const Success(null);
    } catch (e, s) {
      _log.warning('Logout failed', e, s);
      return Failure(ExceptionMapper.map(e, s));
    }
  }
}
