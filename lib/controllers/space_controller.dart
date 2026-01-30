import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/services/cache/secure_cache_service.dart';

// =============================================================================
// SPACE CONTROLLER
// =============================================================================

/// Controller for managing Matrix Spaces.
///
/// Handles:
/// - Loading and caching space hierarchy
/// - Space navigation state
/// - Creating spaces and subspaces
/// - Managing space children (rooms and subspaces)
class SpaceController extends ChangeNotifier {
  // ===========================================================================
  // DEPENDENCIES
  // ===========================================================================

  final Client _client;
  static final Logger _log = Logger('SpaceController');

  // ===========================================================================
  // STATE
  // ===========================================================================

  /// Currently active space ID (null = show all chats)
  String? _activeSpaceId;
  String? get activeSpaceId => _activeSpaceId;

  /// Cached space children for the active space
  List<SpaceRoomsChunk$2> _spaceChildren = [];
  List<SpaceRoomsChunk$2> get spaceChildren => _spaceChildren;

  /// Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Whether there are more rooms to load
  String? _nextBatch;
  bool _noMoreRooms = false;
  bool get canLoadMore => !_noMoreRooms && _nextBatch != null;

  /// Search filter
  String _filter = '';
  String get filter => _filter;

  /// Stream subscription for sync updates
  StreamSubscription<SyncUpdate>? _syncSubscription;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  /// All spaces the user is a member of
  List<Room> get spaces => _client.rooms.where((r) => r.isSpace).toList();

  /// Current active space room
  Room? get activeSpace =>
      _activeSpaceId != null ? _client.getRoomById(_activeSpaceId!) : null;

  /// Filtered space children based on search
  List<SpaceRoomsChunk$2> get filteredChildren {
    if (_filter.isEmpty) return _spaceChildren;
    final lowerFilter = _filter.toLowerCase();
    return _spaceChildren.where((child) {
      final name = child.name?.toLowerCase() ?? '';
      final alias = child.canonicalAlias?.toLowerCase() ?? '';
      return name.contains(lowerFilter) || alias.contains(lowerFilter);
    }).toList();
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  SpaceController(this._client) {
    _setupSyncListener();
  }

  void _setupSyncListener() {
    _syncSubscription?.cancel();
    _syncSubscription = _client.onSync.stream.listen((_) {
      // Notify listeners when rooms change to update space list
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  /// Set the active space and load its hierarchy
  Future<void> setActiveSpace(String spaceId) async {
    if (_activeSpaceId == spaceId) return;

    final room = _client.getRoomById(spaceId);
    if (room == null || !room.isSpace) {
      _log.warning('Attempted to set non-space room as active: $spaceId');
      return;
    }

    _activeSpaceId = spaceId;
    _spaceChildren = [];
    _nextBatch = null;
    _noMoreRooms = false;
    _filter = '';
    notifyListeners();

    await loadSpaceHierarchy();
  }

  /// Clear active space (return to all chats view)
  void clearActiveSpace() {
    _activeSpaceId = null;
    _spaceChildren = [];
    _nextBatch = null;
    _noMoreRooms = false;
    _filter = '';
    notifyListeners();
  }

  /// Update search filter
  void setFilter(String value) {
    _filter = value.trim();
    notifyListeners();
  }

  // ===========================================================================
  // HIERARCHY LOADING
  // ===========================================================================

  // ===========================================================================
  // HIERARCHY LOADING
  // ===========================================================================

  /// Load space hierarchy with caching
  Future<void> loadSpaceHierarchy({bool refresh = false}) async {
    if (_activeSpaceId == null) return;
    if (_isLoading) return;

    final room = _client.getRoomById(_activeSpaceId!);
    if (room == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load from State (Fastest) - ensuring we show what we know immediately
      final stateChildren = room.spaceChildren;
      final localChunks = <SpaceRoomsChunk$2>[];

      for (final child in stateChildren) {
        if (child.roomId == null) continue;
        final childRoom = _client.getRoomById(child.roomId!);

        var name = child.roomId!;
        if (childRoom != null) {
          name = childRoom.getLocalizedDisplayname();
        } else if (child.suggested == true) {
          // name fallback
        }

        localChunks.add(
          SpaceRoomsChunk$2(
            roomId: child.roomId!,
            name: name,
            avatarUrl: childRoom?.avatar,
            topic: childRoom?.topic ?? '',
            numJoinedMembers: childRoom?.summary.mJoinedMemberCount ?? 0,
            canonicalAlias: childRoom?.canonicalAlias ?? '',
            roomType: childRoom?.isSpace == true ? 'm.space' : null,
            worldReadable: false,
            guestCanJoin: false,
            childrenState: [],
          ),
        );
      }

      if (_spaceChildren.isEmpty || refresh) {
        // Only use local chunks if we don't have better data yet
        // OR merge them carefully.
        _spaceChildren = localChunks;
        notifyListeners();
      }

      // 2. Load from Cache (if needed and not refreshing)
      if (!refresh && _spaceChildren.isEmpty) {
        await _loadFromCache();
      }

      // 3. Update from Server
      final hierarchy = await _client.getSpaceHierarchy(
        _activeSpaceId!,
        suggestedOnly: false,
        maxDepth: 1,
        from: refresh ? null : _nextBatch,
      );

      if (refresh) {
        // If refreshing, we keep valid local data until replaced?
        // Actually hierarchy response is authoritative for hierarchy.
        // But we might want to keep "joined" status knowledge from local chunks if hierarchy is missing it?
        // Hierarchy returns SpaceRoomsChunk$2 which has member counts etc.
        _spaceChildren.clear();
      }

      _nextBatch = hierarchy.nextBatch;
      if (hierarchy.nextBatch == null) {
        _noMoreRooms = true;
      }

      // Merge server rooms.
      final serverRooms = hierarchy.rooms
          .where((r) => r.roomId != _activeSpaceId)
          .toList();

      final serverIds = serverRooms.map((r) => r.roomId).toSet();

      for (final r in serverRooms) {
        // If server returns a room, it usually has the name.
        // If name is missing (unlikely from hierarchy), try to fetch preview?
        if (r.name == null || r.name == r.roomId) {
          // Try to find in local store again just in case
          final localRoom = _client.getRoomById(r.roomId);
          if (localRoom != null) {
            r.name = localRoom.getLocalizedDisplayname();
            r.avatarUrl ??= localRoom.avatar;
          }
        }

        final index = _spaceChildren.indexWhere((c) => c.roomId == r.roomId);
        if (index != -1) {
          _spaceChildren[index] = r;
        } else {
          _spaceChildren.add(r);
        }
      }

      // Check for locally known children that weren't in hierarchy
      // (Maybe they are not public or something, but we know them)
      for (final local in localChunks) {
        if (!serverIds.contains(local.roomId)) {
          final index = _spaceChildren.indexWhere(
            (c) => c.roomId == local.roomId,
          );
          if (index == -1) {
            _spaceChildren.add(local);
          }
        }
      }

      // Fix items with missing names using preview
      // We do this concurrently to not block
      // _resolveMissingInfo(); // Disabled

      // Save to cache
      _saveToCache();

      _isLoading = false;
      notifyListeners();
    } catch (e, s) {
      _log.warning('Failed to load space hierarchy', e, s);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more space children (pagination)
  Future<void> loadMore() async {
    if (!canLoadMore || _isLoading) return;
    await loadSpaceHierarchy();
  }

  /// Refresh the space hierarchy
  Future<void> refresh() async {
    _nextBatch = null;
    _noMoreRooms = false;
    await loadSpaceHierarchy(refresh: true);
  }

  // ===========================================================================
  // CACHING
  // ===========================================================================

  Future<void> _loadFromCache() async {
    if (_activeSpaceId == null) return;

    try {
      final cacheKey = 'space_hierarchy_$_activeSpaceId';
      final cachedBytes = await SecureCacheService().get(cacheKey);

      if (cachedBytes != null) {
        // Use compute to parse large JSON off the main thread
        final loadedChildren = await compute(_parseSpaceChildren, cachedBytes);
        if (loadedChildren.isNotEmpty) {
          _spaceChildren = loadedChildren;
          notifyListeners();
        }
      }
    } catch (e) {
      _log.warning('Failed to load space hierarchy from cache', e);
    }
  }

  Future<void> _saveToCache() async {
    if (_activeSpaceId == null) return;

    try {
      final cacheKey = 'space_hierarchy_$_activeSpaceId';

      // Compute JSON encoding off main thread
      // We manually construct the map to ensure we capture the locally resolved
      // names and avatars, in case the SDK's toJson() relies on original raw data.
      final dataParams = _spaceChildren.map((e) {
        final map = e.toJson();
        // Force update fields that might have been resolved locally
        if (e.name != null) map['name'] = e.name;
        if (e.avatarUrl != null) map['avatar_url'] = e.avatarUrl.toString();
        if (e.topic != null) map['topic'] = e.topic;
        return map;
      }).toList();

      final bytes = await compute(_encodeSpaceChildren, dataParams);

      await SecureCacheService().put(cacheKey, bytes, category: 'metadata');
    } catch (e) {
      _log.warning('Failed to save space hierarchy to cache', e);
    }
  }

  // ===========================================================================
  // SPACE OPERATIONS
  // ===========================================================================

  /// Create a new space
  Future<String?> createSpace({
    required String name,
    String? topic,
    bool isPublic = false,
  }) async {
    try {
      final roomId = await _client.createRoom(
        name: name,
        topic: topic,
        visibility: isPublic ? Visibility.public : Visibility.private,
        creationContent: {'type': 'm.space'},
        preset: isPublic
            ? CreateRoomPreset.publicChat
            : CreateRoomPreset.privateChat,
        powerLevelContentOverride: {'events_default': 100},
      );

      _log.info('Created space: $roomId');
      notifyListeners();
      return roomId;
    } catch (e, s) {
      _log.severe('Failed to create space', e, s);
      return null;
    }
  }

  /// Create a subspace within the current active space
  Future<String?> createSubspace({required String name, String? topic}) async {
    if (_activeSpaceId == null) return null;

    final parentSpace = activeSpace;
    if (parentSpace == null) return null;

    final isPublic = parentSpace.joinRules == JoinRules.public;

    try {
      final roomId = await _client.createRoom(
        name: name,
        topic: topic,
        visibility: isPublic ? Visibility.public : Visibility.private,
        creationContent: {'type': 'm.space'},
        preset: isPublic
            ? CreateRoomPreset.publicChat
            : CreateRoomPreset.privateChat,
        powerLevelContentOverride: {'events_default': 100},
      );

      // Add to parent space
      await parentSpace.setSpaceChild(roomId);

      _log.info('Created subspace: $roomId in space: $_activeSpaceId');
      await refresh();
      return roomId;
    } catch (e, s) {
      _log.severe('Failed to create subspace', e, s);
      return null;
    }
  }

  /// Create a group chat within the current active space
  Future<String?> createGroupInSpace({
    required String name,
    bool enableEncryption = true,
  }) async {
    if (_activeSpaceId == null) return null;

    final parentSpace = activeSpace;
    if (parentSpace == null) return null;

    final isPublic = parentSpace.joinRules == JoinRules.public;

    try {
      final roomId = await _client.createGroupChat(
        groupName: name,
        enableEncryption: enableEncryption && !isPublic,
        preset: isPublic
            ? CreateRoomPreset.publicChat
            : CreateRoomPreset.privateChat,
        visibility: isPublic ? Visibility.public : Visibility.private,
        initialState: isPublic
            ? null
            : [
                StateEvent(
                  content: {
                    'join_rule': 'restricted',
                    'allow': [
                      {'room_id': _activeSpaceId, 'type': 'm.room_membership'},
                    ],
                  },
                  type: EventTypes.RoomJoinRules,
                ),
              ],
      );

      // Add to parent space
      await parentSpace.setSpaceChild(roomId);

      _log.info('Created group: $roomId in space: $_activeSpaceId');
      await refresh();
      return roomId;
    } catch (e, s) {
      _log.severe('Failed to create group in space', e, s);
      return null;
    }
  }

  /// Add existing room to current space
  Future<bool> addRoomToSpace(String roomId) async {
    if (_activeSpaceId == null) return false;

    final parentSpace = activeSpace;
    if (parentSpace == null) return false;

    try {
      await parentSpace.setSpaceChild(roomId);
      await refresh();
      return true;
    } catch (e, s) {
      _log.severe('Failed to add room to space', e, s);
      return false;
    }
  }

  /// Remove room from current space
  Future<bool> removeRoomFromSpace(String roomId) async {
    if (_activeSpaceId == null) return false;

    final parentSpace = activeSpace;
    if (parentSpace == null) return false;

    try {
      await parentSpace.removeSpaceChild(roomId);
      await refresh();
      return true;
    } catch (e, s) {
      _log.severe('Failed to remove room from space', e, s);
      return false;
    }
  }

  /// Move room to a different space
  Future<bool> moveRoomToSpace(String roomId, String targetSpaceId) async {
    final targetSpace = _client.getRoomById(targetSpaceId);
    if (targetSpace == null || !targetSpace.isSpace) return false;

    try {
      // Add to new space
      await targetSpace.setSpaceChild(roomId);

      // Remove from current space if active
      if (_activeSpaceId != null) {
        final currentSpace = activeSpace;
        if (currentSpace != null) {
          await currentSpace.removeSpaceChild(roomId);
        }
      }

      await refresh();
      return true;
    } catch (e, s) {
      _log.severe('Failed to move room to space', e, s);
      return false;
    }
  }

  /// Join a room from the space hierarchy
  Future<Room?> joinSpaceChild(SpaceRoomsChunk$2 child) async {
    try {
      var viaList = <String>[];
      final space = activeSpace;
      if (space != null) {
        viaList = space.spaceChildren
            .where((c) => c.roomId == child.roomId)
            .expand((c) => c.via)
            .toList();
      }

      await _client.joinRoom(child.roomId, serverName: viaList);

      await _client.waitForRoomInSync(child.roomId, join: true);
      return _client.getRoomById(child.roomId);
    } catch (e, s) {
      _log.severe('Failed to join space child', e, s);
      return null;
    }
  }

  // ===========================================================================
  // PERMISSIONS
  // ===========================================================================

  /// Check if current user can manage space children
  bool get canManageSpaceChildren {
    final space = activeSpace;
    if (space == null || space.membership != Membership.join) return false;
    // Check if we have the specific power level to send space child events
    return space.canChangeStateEvent(EventTypes.SpaceChild);
  }

  /// Check if current user can invite to space
  bool get canInviteToSpace {
    final space = activeSpace;
    if (space == null) return false;
    return space.canInvite;
  }

  // ===========================================================================
  // UTILITIES
  // ===========================================================================

  /// Get unread count for a space (sum of all children)
  int getSpaceUnreadCount(String spaceId) {
    final space = _client.getRoomById(spaceId);
    if (space == null) return 0;

    final childIds = space.spaceChildren
        .map((c) => c.roomId)
        .whereType<String>()
        .toSet();

    var count = 0;
    for (final room in _client.rooms) {
      if (childIds.contains(room.id) && room.notificationCount > 0) {
        count += room.notificationCount;
      }
    }
    return count;
  }

  /// Check if space has any unread rooms
  bool spaceHasUnread(String spaceId) {
    return getSpaceUnreadCount(spaceId) > 0;
  }
}

// =============================================================================
// ISOLATE FUNCTIONS
// =============================================================================

/// Top-level function for Isolate: Parsing JSON bytes
List<SpaceRoomsChunk$2> _parseSpaceChildren(Uint8List bytes) {
  final jsonStr = utf8.decode(bytes);
  final List<dynamic> jsonList = jsonDecode(jsonStr);
  return jsonList.map((e) => SpaceRoomsChunk$2.fromJson(e)).toList();
}

/// Top-level function for Isolate: Encoding JSON to bytes
Uint8List _encodeSpaceChildren(List<Map<String, dynamic>> jsonList) {
  final jsonStr = jsonEncode(jsonList);
  return utf8.encode(jsonStr);
}
