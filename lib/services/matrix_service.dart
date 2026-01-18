import 'dart:io';

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    // Retrieve or generate secure key for DB encryption
    final dbKey = await _getDatabaseKey();

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

    // TODO: To fully encrypt the database file, we need a SQLCipher-capable sqflite implementation.
    // Currently using standard sqflite_common_ffi.
    // The key generated above can be used once we migrate to a cipher-capable DB factory.
    _log.info(
      'Secure DB key generated/retrieved (ready for SQLCipher integration): ${dbKey.substring(0, 4)}...',
    );

    _client = Client(
      'MonoChat',
      database: database,
      shareKeysWith: ShareKeysWith.all,
      verificationMethods: {
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.emoji,
      },
      supportedLoginTypes: {
        AuthenticationTypes.password,
        AuthenticationTypes.sso,
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
    _client!.onLoginStateChanged.stream.listen((state) async {
      _log.info('Login state changed: $state');
      if (state == LoginState.loggedIn) {
        // Wait for login process to complete its own sync/init
        await Future.delayed(const Duration(seconds: 2));
        BackgroundSyncService.startBackgroundSync(_client!);
      } else if (state == LoginState.loggedOut) {
        BackgroundSyncService.stopBackgroundSync();
      }
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

  Future<String> _getDatabaseKey() async {
    const storage = FlutterSecureStorage();
    const keyName = 'matrix_db_key';

    try {
      // 1. Try Secure Storage
      String? key = await storage.read(key: keyName);

      if (key == null) {
        key = _generateKey();
        await storage.write(key: keyName, value: key);
        _log.info('Generated new secure database key');
      } else {
        _log.info('Retrieved existing secure database key');
      }
      return key;
    } catch (e) {
      _log.warning(
        'Secure storage failed ($e). Falling back to insecure file storage.',
      );
      return await _getInsecureDatabaseKey(keyName);
    }
  }

  Future<String> _getInsecureDatabaseKey(String keyName) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '$keyName.insecure'));

    if (await file.exists()) {
      _log.info('Retrieved existing INSECURE database key');
      return await file.readAsString();
    } else {
      final key = _generateKey();
      await file.writeAsString(key);
      _log.info('Generated new INSECURE database key');
      return key;
    }
  }

  String _generateKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }
}
