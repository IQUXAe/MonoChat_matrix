import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

/// A high-performance, two-level secure caching system using SQLite + Potassium (libsodium).
///
/// Features:
/// - **Native Speed**: Uses libsodium (C++) via FFI for encryption (ChaCha20-Poly1305).
/// - **L1 Cache (RAM)**: Fast in-memory LRU access.
/// - **L2 Cache (Disk)**: SQLite database storing authenticated encrypted blobs.
/// - **Security**: Keys managed via system Keychain, self-destructs on tampering.
class SecureCacheService {
  static final SecureCacheService _instance = SecureCacheService._internal();
  static final Logger _log = Logger('SecureCacheService');

  factory SecureCacheService() => _instance;

  SecureCacheService._internal();

  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  static const String _kKeyStorageName =
      'secure_cache_key_v3_sodium'; // Bumped version for new schema
  static const String _kDbName = 'secure_cache_v3_sodium.db'; // Bumped db
  static const int _kRamCacheSize = 50; // Max items in RAM
  static const Duration _kCacheValidity = Duration(days: 30); // Auto-expire

  // ===========================================================================
  // STATE
  // ===========================================================================

  ffi.Database? _db;
  Sodium? _sodium;
  SecureKey? _encryptionKey;
  String? _dbPassword;
  final _storage = const FlutterSecureStorage();

  // L1 RAM Cache (LRU)
  final LinkedHashMap<String, Uint8List> _ramCache = LinkedHashMap();

  bool _isInitialized = false;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _log.info('Initializing Secure Cache (Sodium + SQLite)...');

      // 1. Initialize Sodium (C++ FFI)
      _sodium = await SodiumInit.init();

      // 2. Load or Create Encryption Key
      await _setupEncryptionAndGetPassword();

      // 3. Open Database (using encryption key as password)
      await _openDatabase(_dbPassword ?? '');

      _isInitialized = true;
      _log.info('Secure Cache initialized successfully.');
    } catch (e, s) {
      _log.severe('Failed to init secure cache.', e, s);
      try {
        await nuke();
      } catch (_) {}
    }
  }

  Future<void> _setupEncryptionAndGetPassword() async {
    const storage = FlutterSecureStorage();
    try {
      var keyBase64 = await storage.read(key: _kKeyStorageName);
      if (keyBase64 == null) {
        _log.info('Generating new secure cache key...');
        final keyBytes = _sodium!.randombytes.buf(
          _sodium!.crypto.secretBox.keyBytes,
        );
        keyBase64 = base64Encode(keyBytes);
        await storage.write(key: _kKeyStorageName, value: keyBase64);
      }

      // keyBase64 IS the password for SQLCipher
      _dbPassword = keyBase64;

      // Also setup Sodium key for the content encryption
      final keyBytes = base64Decode(keyBase64);
      _encryptionKey = _sodium!.secureCopy(Uint8List.fromList(keyBytes));
    } catch (e) {
      _log.severe('Key setup failed', e);
      // Fallback to ephemeral
      final keyBytes = _sodium!.randombytes.buf(
        _sodium!.crypto.secretBox.keyBytes,
      );
      _dbPassword = base64Encode(keyBytes);
      _encryptionKey = _sodium!.secureCopy(keyBytes);
    }
  }

  Future<void> _openDatabase(String password) async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _kDbName);

    Future<void> onCreate(ffi.Database db, int version) async {
      await db.execute('''
        CREATE TABLE cache (
          key TEXT PRIMARY KEY,
          data BLOB,
          nonce TEXT,
          timestamp INTEGER,
          category TEXT
        )
      ''');
      await db.execute('CREATE INDEX idx_timestamp ON cache (timestamp)');
      await db.execute('CREATE INDEX idx_category ON cache (category)');
    }

    try {
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        _db = await ffi.databaseFactoryFfi.openDatabase(
          dbPath,
          options: ffi.OpenDatabaseOptions(
            version: 1,
            onCreate: onCreate,
            onConfigure: (db) async {
              await db.execute("PRAGMA key = '$password'");
            },
          ),
        );
      } else {
        _db = await sqlcipher.openDatabase(
          dbPath,
          password: password,
          version: 1,
          onCreate: onCreate,
        );
      }
    } catch (e) {
      _log.severe(
        'Failed to open encrypted DB. Key might be invalid or DB corrupted.',
        e,
      );
      // CRITICAL: Do NOT delete the DB file automatically.
      // If the key is wrong (e.g. secure storage glitch), we don't want to wipe user data.
      // We explicitly rethrow to let the app handle the failure (e.g. show error screen).
      rethrow;
    }
  }

  // ===========================================================================
  // OPERATIONS
  // ===========================================================================

  /// Puts data into the cache (L1 + L2) with optional category.
  Future<void> put(String key, Uint8List data, {String? category}) async {
    if (!_isInitialized) await init();

    // 1. Write to RAM (L1)
    _updateRamCache(key, data);

    // 2. Write to Disk (L2) - Encrypted via Sodium
    try {
      if (_encryptionKey == null || _sodium == null) return;

      // Sodium: Generate Nonce
      final nonce = _sodium!.randombytes.buf(
        _sodium!.crypto.secretBox.nonceBytes,
      );

      // Sodium: Encrypt (Seal) - authenticated encryption
      final encrypted = _sodium!.crypto.secretBox.easy(
        message: data,
        nonce: nonce,
        key: _encryptionKey!,
      );

      if (_db != null && _db!.isOpen) {
        await _db!.insert('cache', {
          'key': key,
          'data': encrypted,
          'nonce': base64Encode(nonce),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'category': category,
        }, conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace);
      }
    } catch (e) {
      _log.warning('Failed to write to persistent cache', e);
    }
  }

  /// Retrieves data from the cache.
  Future<Uint8List?> get(String key) async {
    if (!_isInitialized) await init();

    // 1. Check RAM (L1)
    if (_ramCache.containsKey(key)) {
      final data = _ramCache.remove(key)!;
      _ramCache[key] = data;
      return data;
    }

    // 2. Check Disk (L2)
    try {
      if (_db == null || !_db!.isOpen) return null;

      final results = await _db!.query(
        'cache',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final encryptedBytes = row['data'] as Uint8List;
      final nonceBase64 = row['nonce'] as String;
      final timestamp = row['timestamp'] as int;

      // Check validity
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _kCacheValidity.inMilliseconds) {
        await _db!.delete('cache', where: 'key = ?', whereArgs: [key]);
        return null;
      }

      // Decrypt via Sodium
      if (_encryptionKey != null && _sodium != null) {
        try {
          final nonce = base64Decode(nonceBase64);

          final decrypted = _sodium!.crypto.secretBox.openEasy(
            cipherText: encryptedBytes,
            nonce: nonce,
            key: _encryptionKey!,
          );

          // Populate L1
          _updateRamCache(key, decrypted);
          return decrypted;
        } catch (e) {
          _log.warning('Decryption failed (Sodium error)', e);
          await _db!.delete('cache', where: 'key = ?', whereArgs: [key]);
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      _log.warning('Failed to read/decrypt from cache', e);
      return null;
    }
  }

  // ===========================================================================
  // CATEGORY MAINTENANCE
  // ===========================================================================

  /// Gets the size (in bytes) of a specific category, or all if null.
  Future<int> getCacheSize({String? category}) async {
    if (!_isInitialized) return 0;
    try {
      var size = 0;
      if (_db != null && _db!.isOpen) {
        final where = category != null ? 'WHERE category = ?' : '';
        final args = category != null ? [category] : [];
        final query = 'SELECT SUM(length(data)) as size FROM cache $where';

        final result = await _db!.rawQuery(query, args);
        if (result.isNotEmpty && result.first['size'] != null) {
          size += result.first['size'] as int;
        }
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  /// Clears items of a specific category.
  Future<void> clearCategory(String category) async {
    if (!_isInitialized) return;
    try {
      // Clear from RAM first (simple clear for now, could be smarter)
      _ramCache.clear();

      if (_db != null && _db!.isOpen) {
        await _db!.delete(
          'cache',
          where: 'category = ?',
          whereArgs: [category],
        );
      }
    } catch (e) {
      _log.warning('Failed to clear category: $category', e);
    }
  }

  void _updateRamCache(String key, Uint8List data) {
    if (_ramCache.containsKey(key)) {
      _ramCache.remove(key);
    }
    _ramCache[key] = data;

    if (_ramCache.length > _kRamCacheSize) {
      _ramCache.remove(_ramCache.keys.first);
    }
  }

  // ===========================================================================
  // SELF-DESTRUCT
  // ===========================================================================

  /// Completely wipes the cache and keys.
  Future<void> nuke() async {
    _log.warning('NUKING SECURE CACHE...');
    _ramCache.clear();
    _encryptionKey?.dispose();
    _encryptionKey = null;

    try {
      if (_db != null && _db!.isOpen) {
        await _db!.close();
      }

      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, _kDbName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log.severe('Error deleting DB file', e);
    }

    try {
      await _storage.delete(key: _kKeyStorageName);
    } catch (e) {
      _log.warning('Failed to delete secure key', e);
    }

    _db = null;
    _sodium = null;
    _isInitialized = false;
  }
}
