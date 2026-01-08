import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:matrix/matrix.dart' hide Result;

import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/core/result.dart';
import 'package:monochat/core/exceptions/app_exception.dart';

import '../mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late AuthController controller;
  late StreamController<LoginState> loginStateController;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    loginStateController = StreamController<LoginState>.broadcast();

    // Default stubs
    when(() => mockAuthRepo.client).thenReturn(null);
    when(
      () => mockAuthRepo.loginStateStream,
    ).thenAnswer((_) => loginStateController.stream);
    when(() => mockAuthRepo.isLoggedIn).thenReturn(false);
    when(
      () => mockAuthRepo.initialize(),
    ).thenAnswer((_) async => const Success(null));
  });

  tearDown(() {
    loginStateController.close();
  });

  group('AuthController', () {
    group('Initialization', () {
      test('starts in initializing state', () {
        controller = AuthController(mockAuthRepo);
        expect(controller.state, AuthState.initializing);
      });

      test('transitions to unauthenticated when no session', () async {
        when(() => mockAuthRepo.isLoggedIn).thenReturn(false);

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.unauthenticated);
      });

      test('transitions to authenticated when session exists', () async {
        when(() => mockAuthRepo.isLoggedIn).thenReturn(true);

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.authenticated);
      });

      test('transitions to error state when initialization fails', () async {
        when(() => mockAuthRepo.initialize()).thenAnswer(
          (_) async => const Failure(GenericException('Init failed')),
        );

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.error);
        expect(controller.errorMessage, isNotNull);
      });
    });

    group('Login', () {
      test('calls repository login with correct parameters', () async {
        when(
          () => mockAuthRepo.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            homeserver: any(named: 'homeserver'),
          ),
        ).thenAnswer((_) async => const Success(null));

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        await controller.login('user', 'pass', 'matrix.org');

        verify(
          () => mockAuthRepo.login(
            username: 'user',
            password: 'pass',
            homeserver: 'matrix.org',
          ),
        ).called(1);
      });

      test('throws user message when login fails', () async {
        when(
          () => mockAuthRepo.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            homeserver: any(named: 'homeserver'),
          ),
        ).thenAnswer((_) async => const Failure(InvalidCredentialsException()));

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(
          () => controller.login('user', 'wrong', 'matrix.org'),
          throwsA(isA<String>()),
        );
      });
    });

    group('Login State Stream', () {
      test('updates to authenticated when stream emits loggedIn', () async {
        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.unauthenticated);

        loginStateController.add(LoginState.loggedIn);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.authenticated);
      });

      test('updates to unauthenticated when stream emits loggedOut', () async {
        when(() => mockAuthRepo.isLoggedIn).thenReturn(true);
        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.authenticated);

        loginStateController.add(LoginState.loggedOut);
        await Future.delayed(Duration.zero);

        expect(controller.state, AuthState.unauthenticated);
      });
    });

    group('Retry', () {
      test('reinitializes when retry is called', () async {
        when(
          () => mockAuthRepo.initialize(),
        ).thenAnswer((_) async => const Success(null));

        controller = AuthController(mockAuthRepo);
        await Future.delayed(Duration.zero);

        await controller.retry();

        verify(() => mockAuthRepo.initialize()).called(2);
      });
    });
  });
}
