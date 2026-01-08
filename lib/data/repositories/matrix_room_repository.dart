import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart' hide Result;

import '../../core/exceptions/app_exception.dart';
import '../../core/exceptions/exception_mapper.dart';
import '../../core/result.dart';
import '../../domain/repositories/room_repository.dart';
import '../../services/matrix_service.dart';

/// Matrix SDK implementation of [RoomRepository].
class MatrixRoomRepository implements RoomRepository {
  final MatrixService _service;
  static final Logger _log = Logger('MatrixRoomRepository');

  MatrixRoomRepository(this._service);

  Client? get _client => _service.client;

  @override
  List<Room> get rooms => _client?.rooms ?? [];

  @override
  Stream<SyncUpdate> get syncStream =>
      _client?.onSync.stream ?? const Stream.empty();

  @override
  Stream<LoginState> get loginStateStream =>
      _client?.onLoginStateChanged.stream ?? const Stream.empty();

  @override
  Room? getRoomById(String roomId) => _client?.getRoomById(roomId);

  @override
  Future<Result<String>> createDirectChat(String mxid) async {
    try {
      if (_client == null) {
        return const Failure(ClientNotInitializedException());
      }
      final roomId = await _client!.startDirectChat(mxid);
      return Success(roomId);
    } catch (e, s) {
      _log.warning('Failed to create direct chat', e, s);
      return Failure(ExceptionMapper.map(e, s));
    }
  }

  @override
  Future<Result<String>> createGroupChat({
    required String name,
    List<String> invites = const [],
  }) async {
    try {
      if (_client == null) {
        return const Failure(ClientNotInitializedException());
      }
      final roomId = await _client!.createGroupChat(
        groupName: name,
        invite: invites,
      );
      return Success(roomId);
    } catch (e, s) {
      _log.warning('Failed to create group chat', e, s);
      return Failure(RoomCreationFailedException(debugInfo: e.toString()));
    }
  }
}
