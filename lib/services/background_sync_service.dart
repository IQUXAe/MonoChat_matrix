import 'dart:async';
import 'package:matrix/matrix.dart';
import 'package:logging/logging.dart';

/// Service for background synchronization to maintain server connection without blocking UI.
class BackgroundSyncService {
  static final Logger _log = Logger('BackgroundSyncService');
  static Client? _client;
  static Timer? _syncTimer;
  static Timer? _heartbeatTimer;
  static bool _isActive = false;
  static int _syncInterval = 30; // 30 seconds
  static int _heartbeatInterval = 30;

  static Future<void> startBackgroundSync(Client client) async {
    _client = client;

    _isActive = true;
    _startSyncLoop();
    _startHeartbeatLoop();
    _log.info('Background sync started');
  }

  static void stopBackgroundSync() {
    _isActive = false;
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer = null;
    _heartbeatTimer = null;
    _log.info('Background sync stopped');
  }

  static void _startSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: _syncInterval), (timer) {
      if (_isActive && _client != null) {
        _performBackgroundSync();
      }
    });
  }

  static void _startHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (
      timer,
    ) {
      if (_isActive && _client != null) {
        _performHeartbeat();
      }
    });
  }

  static Future<void> _performBackgroundSync() async {
    if (_client == null) return;

    try {
      // Perform a lightweight one-shot sync
      await _client!.oneShotSync(timeout: const Duration(seconds: 10));
      _log.fine('Sync iteration completed');
    } catch (e) {
      _log.warning('Sync failed: $e');
      // Try heartbeat on failure
      await _performHeartbeat();
    }
  }

  static Future<void> _performHeartbeat() async {
    if (_client == null) return;

    try {
      final userID = _client!.userID;
      if (userID != null) {
        await _client!.getProfileFromUserId(userID);
      }
    } catch (e) {
      _log.fine('Heartbeat failed: $e');
    }
  }

  static void updateSyncInterval(int seconds) {
    _syncInterval = seconds;
    if (_isActive) {
      _startSyncLoop();
    }
  }
}
