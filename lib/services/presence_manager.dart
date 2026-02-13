import 'dart:async';
import 'package:matrix/matrix.dart';

class PresenceManager {
  static final PresenceManager _instance = PresenceManager._internal();
  factory PresenceManager() => _instance;
  PresenceManager._internal();

  // Map client to its specific listeners manager
  final Map<Client, _ClientPresenceManager> _managers = {};

  void listen(
    Client client,
    String userId,
    void Function(CachedPresence) callback,
  ) {
    if (!_managers.containsKey(client)) {
      _managers[client] = _ClientPresenceManager(client);
    }
    _managers[client]!.addListener(userId, callback);
  }

  void unlisten(
    Client client,
    String userId,
    void Function(CachedPresence) callback,
  ) {
    if (_managers.containsKey(client)) {
      final manager = _managers[client]!;
      manager.removeListener(userId, callback);

      // Clean up if no listeners remain for this client
      if (manager.isEmpty) {
        manager.dispose();
        _managers.remove(client);
      }
    }
  }
}

class _ClientPresenceManager {
  final Client client;
  StreamSubscription<CachedPresence>? _subscription;

  // userId -> Set of callbacks
  final Map<String, Set<void Function(CachedPresence)>> _listeners = {};

  _ClientPresenceManager(this.client) {
    _subscription = client.onPresenceChanged.stream.listen(_onPresenceUpdate);
  }

  bool get isEmpty => _listeners.isEmpty;

  void _onPresenceUpdate(CachedPresence presence) {
    // Note: 'userid' is the property name in CachedPresence as per existing code usage
    final listeners = _listeners[presence.userid];
    if (listeners != null) {
      for (final listener in listeners) {
        listener(presence);
      }
    }
  }

  void addListener(String userId, void Function(CachedPresence) listener) {
    if (!_listeners.containsKey(userId)) {
      _listeners[userId] = {};
    }
    _listeners[userId]!.add(listener);
  }

  void removeListener(String userId, void Function(CachedPresence) listener) {
    if (_listeners.containsKey(userId)) {
      final listeners = _listeners[userId]!;
      listeners.remove(listener);
      if (listeners.isEmpty) {
        _listeners.remove(userId);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }
}
