import 'dart:io';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:logging/logging.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'background_sync_service.dart';

// =============================================================================
// MATRIX SERVICE
// =============================================================================

/// Singleton service for Matrix client initialization.
///
/// Handles:
/// - Database setup (SQLite with FFI for desktop)
/// - E2EE initialization (vodozemac)
/// - Client creation and configuration
/// - Background sync startup
///
/// Note: Actual auth and messaging operations should use the
/// repository pattern (MatrixAuthRepository, MatrixChatRepository).
class MatrixService {
  // ===========================================================================
  // SINGLETON
  // ===========================================================================

  static final MatrixService _instance = MatrixService._internal();
  static final Logger _log = Logger('MatrixService');

  factory MatrixService() => _instance;

  MatrixService._internal();

  // ===========================================================================
  // STATE
  // ===========================================================================

  Client? _client;

  /// The Matrix client, or null if not initialized.
  Client? get client => _client;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  /// Initializes the Matrix client.
  ///
  /// This only needs to be called once at app startup.
  /// Subsequent calls are no-ops.
  Future<void> init() async {
    if (_client != null) return;

    _log.info('Initializing dependencies...');

    // Initialize FFI for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'monochat_matrix_v2.sqlite');

    _log.info('DB Path: $dbPath');

    // Initialize vodozemac for E2EE
    await vod.init();

    final database = await MatrixSdkDatabase.init(
      'MonoChat',
      database: await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 1, onCreate: (db, version) {}),
      ),
    );

    _client = Client(
      'MonoChat',
      database: database,
      shareKeysWith: ShareKeysWith.all,
      verificationMethods: {
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.emoji,
      },
    );

    _log.info('Calling client.init()...');
    await _client!.init();
    _log.info('Client initialized. Logged in: ${_client!.isLogged()}');

    // Start background sync if logged in
    if (_client!.isLogged()) {
      BackgroundSyncService.startBackgroundSync(_client!);
    }

    // Setup listeners
    _client!.onLoginStateChanged.stream.listen((state) {
      _log.info('Login state changed: $state');
    });
  }

  // ===========================================================================
  // DEPRECATED - Use repositories instead
  // ===========================================================================

  /// @deprecated Use MatrixAuthRepository.login() instead.
  Future<void> login(
    String username,
    String password,
    String homeserver,
  ) async {
    throw UnimplementedError('Use MatrixAuthRepository.login() instead');
  }

  /// @deprecated Use MatrixChatRepository.sendTextMessage() instead.
  Future<void> sendMessage(String roomId, String message) async {
    throw UnimplementedError(
      'Use MatrixChatRepository.sendTextMessage() instead',
    );
  }
}
