import 'package:matrix/matrix.dart' hide Result;

import '../../core/result.dart';

/// Abstract repository for room operations.
///
/// Provides an abstraction over Matrix room management
/// for better testability and separation of concerns.
abstract class RoomRepository {
  /// List of all joined rooms.
  List<Room> get rooms;

  /// Stream of sync updates from the Matrix server.
  Stream<SyncUpdate> get syncStream;

  /// Stream of login state changes.
  Stream<LoginState> get loginStateStream;

  /// Gets a room by its ID.
  ///
  /// Returns null if the room is not found.
  Room? getRoomById(String roomId);

  /// Creates a direct chat with another user.
  ///
  /// Returns [Success] with the room ID if successful,
  /// or [Failure] with a [RoomException] if it fails.
  Future<Result<String>> createDirectChat(String mxid);

  /// Creates a group chat with the given name.
  ///
  /// Optionally invites the specified users to the room.
  ///
  /// Returns [Success] with the room ID if successful,
  /// or [Failure] with a [RoomException] if it fails.
  Future<Result<String>> createGroupChat({
    required String name,
    List<String> invites = const [],
  });

  /// Searches for users in the user directory.
  Future<Result<List<Profile>>> searchUsers(String query);
}
