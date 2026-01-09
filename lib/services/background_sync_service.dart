import 'dart:async';

import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

// =============================================================================
// BACKGROUND SYNC SERVICE
// =============================================================================

/// Service for background synchronization.
///
/// Maintains server connection without blocking UI by:
/// - Performing periodic sync operations
/// - Sending heartbeat requests to prevent connection drops
class BackgroundSyncService {
  static final Logger _log = Logger('BackgroundSyncService');

  // ===========================================================================
  // STATE
  // ===========================================================================

  static Client? _client;
  static Timer? _syncTimer;
  static Timer? _heartbeatTimer;
  static bool _isActive = false;

  static const int _defaultSyncInterval = 30; // seconds
  static const int _heartbeatInterval = 30; // seconds

  static int _syncInterval = _defaultSyncInterval;

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Starts background sync for the given client.
  static Future<void> startBackgroundSync(Client client) async {
    _client = client;
    _isActive = true;

    _startSyncLoop();
    _startHeartbeatLoop();

    _log.info('Background sync started');
  }

  /// Stops background sync.
  static void stopBackgroundSync() {
    _isActive = false;
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer = null;
    _heartbeatTimer = null;
    _log.info('Background sync stopped');
  }

  /// Updates the sync interval (in seconds).
  static void updateSyncInterval(int seconds) {
    _syncInterval = seconds;
    if (_isActive) {
      _startSyncLoop();
    }
  }

  // ===========================================================================
  // INTERNAL
  // ===========================================================================

  static void _startSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: _syncInterval), (_) {
      if (_isActive && _client != null) {
        _performBackgroundSync();
      }
    });
  }

  static void _startHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatInterval),
      (_) {
        if (_isActive && _client != null) {
          _performHeartbeat();
        }
      },
    );
  }

  static Future<void> _performBackgroundSync() async {
    if (_client == null) return;

    try {
      await _client!.oneShotSync(timeout: const Duration(seconds: 10));
      _log.fine('Sync iteration completed');
    } catch (e) {
      _log.warning('Sync failed: $e');
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
}
