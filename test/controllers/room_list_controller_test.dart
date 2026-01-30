import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:mocktail/mocktail.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/core/exceptions/app_exception.dart';
import 'package:monochat/core/result.dart';

import '../mocks.dart';

void main() {
  late MockRoomRepository mockRoomRepo;
  late RoomListController controller;
  late StreamController<SyncUpdate> syncController;
  late StreamController<LoginState> loginStateController;

  setUpAll(registerFallbackValues);

  setUp(() {
    mockRoomRepo = MockRoomRepository();
    syncController = StreamController<SyncUpdate>.broadcast();
    loginStateController = StreamController<LoginState>.broadcast();

    // Default stubs
    when(() => mockRoomRepo.rooms).thenReturn([]);
    when(
      () => mockRoomRepo.syncStream,
    ).thenAnswer((_) => syncController.stream);
    when(
      () => mockRoomRepo.loginStateStream,
    ).thenAnswer((_) => loginStateController.stream);
  });

  tearDown(() {
    syncController.close();
    loginStateController.close();
  });

  group('RoomListController', () {
    test('starts with empty rooms when no rooms exist', () {
      controller = RoomListController(mockRoomRepo);
      expect(controller.sortedRooms, isEmpty);
    });

    test('isPreloading starts false when no rooms', () {
      controller = RoomListController(mockRoomRepo);
      expect(controller.isPreloading, isFalse);
    });

    test('createDirectChat calls repository', () async {
      when(
        () => mockRoomRepo.createDirectChat(any()),
      ).thenAnswer((_) async => const Success('!room:test'));

      controller = RoomListController(mockRoomRepo);
      final result = await controller.createDirectChat('@user:test');

      expect(result, '!room:test');
      verify(() => mockRoomRepo.createDirectChat('@user:test')).called(1);
    });

    test('createDirectChat returns null on failure', () async {
      when(
        () => mockRoomRepo.createDirectChat(any()),
      ).thenAnswer((_) async => const Failure(RoomCreationFailedException()));

      controller = RoomListController(mockRoomRepo);
      final result = await controller.createDirectChat('@user:test');

      expect(result, isNull);
    });

    test('createGroupChat calls repository with correct params', () async {
      when(
        () => mockRoomRepo.createGroupChat(
          name: any(named: 'name'),
          invites: any(named: 'invites'),
        ),
      ).thenAnswer((_) async => const Success('!group:test'));

      controller = RoomListController(mockRoomRepo);
      final result = await controller.createGroupChat('Test Group', [
        '@user1:test',
        '@user2:test',
      ]);

      expect(result, '!group:test');
      verify(
        () => mockRoomRepo.createGroupChat(
          name: 'Test Group',
          invites: ['@user1:test', '@user2:test'],
        ),
      ).called(1);
    });

    test('clears rooms on logout', () async {
      final mockRoom = MockRoom();
      when(() => mockRoomRepo.rooms).thenReturn([mockRoom]);

      controller = RoomListController(mockRoomRepo);

      // Simulate logout
      loginStateController.add(LoginState.loggedOut);
      await Future.delayed(Duration.zero);

      expect(controller.sortedRooms, isEmpty);
      expect(controller.isPreloading, isFalse);
    });
  });
}
