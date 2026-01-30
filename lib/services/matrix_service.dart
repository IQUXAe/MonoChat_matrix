import 'dart:ffi'; // For DynamicLibrary
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:logging/logging.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/core/network/app_http_client.dart';
import 'package:monochat/utils/background_push.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqlite3/open.dart';

import 'background_sync_service.dart';

DynamicLibrary _loadDynamicLibrary(String name) {
  if (Platform.isLinux) {
    try {
      return DynamicLibrary.open('lib$name.so');
    } catch (_) {
      try {
        return DynamicLibrary.open('/usr/lib/lib$name.so');
      } catch (_) {
        return DynamicLibrary.open('/usr/local/lib/lib$name.so');
      }
    }
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$name.dll');
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('lib$name.dylib');
  }
  throw UnsupportedError('This platform is not supported.');
}

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
  // ACTIVE ROOM TRACKING (for push notification filtering)
  // ===========================================================================

  /// Currently active/open room ID for push notification filtering.
  /// When a user is viewing a room, we don't want to show notifications for it.
  String? _activeRoomId;

  /// Get the currently active room ID.
  String? get activeRoomId => _activeRoomId;

  /// Set the active room ID when entering a chat.
  void setActiveRoom(String? roomId) {
    _activeRoomId = roomId;
  }

  // ===========================================================================
  // PRIVACY SETTINGS
  // ===========================================================================

  bool _sendReadReceipts = true;
  bool get sendReadReceipts => _sendReadReceipts;

  bool _sendTypingIndicators = true;
  bool get sendTypingIndicators => _sendTypingIndicators;

  Future<void> setSendReadReceipts(bool value) async {
    _sendReadReceipts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('send_read_receipts', value);
  }

  Future<void> setSendTypingIndicators(bool value) async {
    _sendTypingIndicators = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('send_typing_indicators', value);
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  /// Initializes the Matrix client.
  ///
  /// This only needs to be called once at app startup.
  /// Subsequent calls are no-ops.
  Future<void> init({bool startSync = true}) async {
    if (_client != null) return;

    _log.info('Initializing dependencies...');

    final prefs = await SharedPreferences.getInstance();
    _sendReadReceipts = prefs.getBool('send_read_receipts') ?? true;
    _sendTypingIndicators = prefs.getBool('send_typing_indicators') ?? true;

    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Force usage of 'sqlcipher' dynamic library instead of 'sqlite3'
      open.overrideFor(OperatingSystem.linux, () {
        // On Linux, user must have libsqlcipher.so installed or bundled
        return _loadDynamicLibrary('sqlcipher_flutter_libs_plugin');
      });
      open.overrideFor(OperatingSystem.windows, () {
        return _loadDynamicLibrary('sqlcipher_flutter_libs_plugin');
      });
      open.overrideFor(OperatingSystem.macOS, () {
        return _loadDynamicLibrary('sqlcipher_flutter_libs_plugin');
      });

      ffi.sqfliteFfiInit();
      // Set the global database factory to FFI, but cast it so sqflite_sqlcipher can use it
      // Note: sqflite_sqlcipher usually detects FFI, but explicit setup is safer
      // databaseFactory = ffi.databaseFactoryFfi;
    }

    // Retrieve or generate secure key for DB encryption
    final dbKey = await _getDatabaseKey();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'monochat_matrix_v2.sqlite');

    _log.info('DB Path: $dbPath');

    // Initialize vodozemac for E2EE
    await vod.init();

    // Note: SQLCipher on FFI (Linux/Desktop) requires manual setup of libraries.
    // If running on Linux without correct setup, this might fail or not be encrypted.
    ffi.Database database;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      database = await ffi.databaseFactoryFfi.openDatabase(
        dbPath,
        options: ffi.OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) {},
          onConfigure: (db) async {
            await db.execute("PRAGMA key = '$dbKey'");
          },
        ),
      );
    } else {
      database = await sqlcipher.openDatabase(
        dbPath,
        password: dbKey,
        version: 1,
        onCreate: (db, version) {},
      );
    }

    final matrixSdkDatabase = await MatrixSdkDatabase.init(
      'MonoChat',
      database: database,
    );

    _log.info('Secure DB initialized with key: ${dbKey.substring(0, 4)}...');

    _client = Client(
      'MonoChat',
      database: matrixSdkDatabase,
      httpClient: AppHttpClient(),
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

    // Start background sync if logged in and requested
    if (startSync && _client!.isLogged()) {
      BackgroundSyncService.startBackgroundSync(_client!);
    }

    // Initialize BackgroundPush
    final bgPush = BackgroundPush.clientOnly(_client!);
    bgPush.setupPush();

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

  Future<String> _getDatabaseKey() async {
    const storage = FlutterSecureStorage();
    const keyName = 'matrix_db_key';

    // 1. Try Secure Storage
    var key = await storage.read(key: keyName);

    if (key == null) {
      key = _generateKey();
      await storage.write(key: keyName, value: key);
      _log.info('Generated new secure database key');
    } else {
      _log.info('Retrieved existing secure database key');
    }
    return key;
  }

  String _generateKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }
}
