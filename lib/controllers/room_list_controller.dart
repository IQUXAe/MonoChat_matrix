import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

import '../domain/repositories/room_repository.dart';

// =============================================================================
// ROOM LIST CONTROLLER
// =============================================================================

/// Controller for the room list screen.
///
/// Manages room list state and operations:
/// - Loading and sorting rooms by last activity
/// - Real-time updates via sync stream
/// - Room creation (direct chats and groups)
///
/// Uses [RoomRepository] abstraction for better testability
/// and separation from Matrix SDK implementation details.
class RoomListController extends ChangeNotifier {
  // ===========================================================================
  // DEPENDENCIES
  // ===========================================================================

  final RoomRepository _roomRepository;
  static final Logger _log = Logger('RoomListController');

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<Room> _sortedRooms = [];
  List<Room> get sortedRooms => _sortedRooms;

  bool _isPreloading = true;
  bool get isPreloading => _isPreloading;

  // ===========================================================================
  // INTERNAL
  // ===========================================================================

  StreamSubscription<SyncUpdate>? _syncSubscription;
  StreamSubscription<LoginState>? _loginSubscription;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  RoomListController(this._roomRepository) {
    _init();
  }

  void _init() {
    // Initial check - if we have rooms, start loading
    if (_roomRepository.rooms.isNotEmpty) {
      _startLoadingSequence();
    } else {
      _isPreloading = false;
    }

    // Listen to login state
    _loginSubscription = _roomRepository.loginStateStream.listen((state) {
      if (state == LoginState.loggedIn) {
        _isPreloading = true;
        notifyListeners();
        _startLoadingSequence();
      } else {
        _syncSubscription?.cancel();
        _sortedRooms = [];
        _isPreloading = false;
        notifyListeners();
      }
    });
  }

  void _startLoadingSequence() {
    _setupSyncListener();
    _updateSortedRooms();
    _preloadAssets();
  }

  void _setupSyncListener() {
    _syncSubscription?.cancel();
    _syncSubscription = _roomRepository.syncStream.listen((_) {
      _updateSortedRooms();
      notifyListeners();
    });
  }

  void _updateSortedRooms() {
    final rooms = List<Room>.from(_roomRepository.rooms);
    rooms.sort((a, b) {
      final aTime =
          a.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastEvent?.originServerTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    _sortedRooms = rooms;
  }

  Future<void> _preloadAssets() async {
    _log.fine('Preloading assets...');

    final count = _sortedRooms.length < 30 ? _sortedRooms.length : 30;
    final roomsToPreload = _sortedRooms.sublist(0, count);

    final futures = roomsToPreload.map((room) async {
      try {
        room.getLocalizedDisplayname();
      } catch (_) {
        // Ignore preload errors
      }
    });

    try {
      await Future.wait(futures).timeout(const Duration(milliseconds: 2500));
    } catch (e) {
      _log.warning('Preload timed out', e);
    } finally {
      _isPreloading = false;
      notifyListeners();
      _log.fine('Preload complete, UI unblocked.');
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _loginSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Creates a direct chat with the given Matrix ID.
  ///
  /// Returns the room ID on success, or null on failure.
  Future<String?> createDirectChat(String mxid) async {
    final result = await _roomRepository.createDirectChat(mxid);
    return result.fold((roomId) => roomId, (exception) {
      _log.warning('Failed to create direct chat: ${exception.message}');
      return null;
    });
  }

  Future<String?> createGroupChat(String name, List<String> invites) async {
    final result = await _roomRepository.createGroupChat(
      name: name,
      invites: invites,
    );
    return result.fold((roomId) => roomId, (exception) {
      _log.warning('Failed to create group chat: ${exception.message}');
      return null;
    });
  }

  /// Searches the user directory.
  Future<List<Profile>> searchUsers(String query) async {
    final result = await _roomRepository.searchUsers(query);
    return result.fold((users) => users, (_) => []);
  }
}
