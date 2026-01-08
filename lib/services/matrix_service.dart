import 'dart:io';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/encryption.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'background_sync_service.dart';

class MatrixService {
  static final MatrixService _instance = MatrixService._internal();
  static final Logger _log = Logger('MatrixService');

  factory MatrixService() {
    return _instance;
  }

  MatrixService._internal();

  Client? _client;

  Client? get client => _client;

  Future<void> init() async {
    if (_client != null) return;

    _log.info("Initializing dependencies...");

    // Initialize FFI for Linux/Windows/MacOS
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'monochat_matrix_v2.sqlite');

    _log.info("DB Path: $dbPath");

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

    _log.info("Calling client.init()...");
    await _client!.init();
    _log.info("Client initialized. Logged in: ${_client!.isLogged()}");

    // Start background sync service to handle syncs efficiently
    if (_client!.isLogged()) {
      BackgroundSyncService.startBackgroundSync(_client!);
    }

    _client!.onSync.stream.listen((SyncUpdate syncUpdate) {
      // background sync logs
    });

    _client!.onLoginStateChanged.stream.listen((LoginState state) {
      _log.info("Login state changed: $state");
    });
  }

  Future<void> login(
    String username,
    String password,
    String homeserver,
  ) async {
    // Deprecated: Use MatrixAuthRepository.login() instead
    throw UnimplementedError('Use MatrixAuthRepository.login() instead');
  }

  Future<void> sendMessage(String roomId, String message) async {
    // Deprecated: Use MatrixChatRepository.sendTextMessage() instead
    throw UnimplementedError(
      'Use MatrixChatRepository.sendTextMessage() instead',
    );
  }
}
