import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

// ===========================================================================
// ISOLATE DECRYPTION (Top-level for compute())
// ===========================================================================

/// Parameters for background decryption - must be serializable.
class _DecryptParams {
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List rawKey;

  _DecryptParams({
    required this.cipherText,
    required this.nonce,
    required this.mac,
    required this.rawKey,
  });
}

/// Top-level function for isolate execution.
/// Pure Dart cryptography works perfectly in isolates!
Future<Uint8List> _decryptInIsolate(_DecryptParams params) async {
  final algorithm = Chacha20.poly1305Aead();
  final secretKey = SecretKey(params.rawKey);

  final secretBox = SecretBox(
    params.cipherText,
    nonce: params.nonce,
    mac: Mac(params.mac),
  );

  final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
  return Uint8List.fromList(decrypted);
}

/// A high-performance, two-level secure caching system using SQLite + cryptography.
///
/// Features:
/// - **Isolate-Safe**: Uses pure Dart cryptography that works in any isolate.
/// - **L1 Cache (RAM)**: Fast in-memory LRU access.
/// - **L2 Cache (Disk)**: SQLite database storing authenticated encrypted blobs.
/// - **Security**: Keys managed via system Keychain, ChaCha20-Poly1305 encryption.
class SecureCacheService {
  static final SecureCacheService _instance = SecureCacheService._internal();
  static final Logger _log = Logger('SecureCacheService');

  factory SecureCacheService() => _instance;

  SecureCacheService._internal();

  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  static const String _kKeyStorageName =
      'secure_cache_key_v4_crypto'; // Bumped version for new crypto lib
  static const String _kDbName = 'secure_cache_v4_crypto.db'; // Bumped db
  static const int _kRamCacheSize =
      500; // Max items in RAM (Increased for smooth scrolling)
  static const Duration _kCacheValidity = Duration(days: 30); // Auto-expire

  // Threshold for async decryption (100 KB)
  static const int _kAsyncDecryptThreshold = 100 * 1024;

  // ===========================================================================
  // STATE
  // ===========================================================================

  ffi.Database? _db;
  final Chacha20 _algorithm = Chacha20.poly1305Aead();
  SecretKey? _encryptionKey;
  Uint8List? _rawKey;
  String? _dbPassword;
  final _storage = const FlutterSecureStorage();

  // L1 RAM Cache (LRU)
  final LinkedHashMap<String, Uint8List> _ramCache = LinkedHashMap();

  bool _isInitialized = false;

  /// Completer used to coalesce concurrent init() calls.
  /// All callers await the same Future, preventing duplicate initialization.
  Completer<void>? _initCompleter;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> init() async {
    // Fast path: already initialized
    if (_isInitialized) return;

    // If init is already in progress, await the same Future instead of
    // starting a second initialization (this was the race condition).
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      _log.info('Initializing Secure Cache (Cryptography + SQLite)...');

      // 1. Load or Create Encryption Key
      await _setupEncryptionAndGetPassword();

      // 2. Open Database (using encryption key as password)
      await _openDatabase(_dbPassword ?? '');

      _isInitialized = true;
      _log.info('Secure Cache initialized successfully.');
      _initCompleter!.complete();
    } catch (e, s) {
      _log.severe('Failed to init secure cache.', e, s);
      _initCompleter!.completeError(e, s);
      _initCompleter = null; // Allow retry on next call
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
        // Generate 32 bytes for ChaCha20
        final keyBytes = SecretKeyData.random(length: 32);
        final bytes = await keyBytes.extractBytes();
        keyBase64 = base64Encode(bytes);
        await storage.write(key: _kKeyStorageName, value: keyBase64);
      }

      // keyBase64 IS the password for SQLCipher
      _dbPassword = keyBase64;

      // Also setup encryption key for content encryption
      final keyBytes = base64Decode(keyBase64);
      _rawKey = Uint8List.fromList(keyBytes);
      _encryptionKey = SecretKey(keyBytes);
    } catch (e) {
      _log.severe('Key setup failed', e);
      // Fallback to ephemeral
      final keyBytes = SecretKeyData.random(length: 32);
      final bytes = await keyBytes.extractBytes();
      _dbPassword = base64Encode(bytes);
      _rawKey = Uint8List.fromList(bytes);
      _encryptionKey = SecretKey(bytes);
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
          mac TEXT,
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
              await db.execute(
                "PRAGMA key = '${password.replaceAll("'", "''")}'",
              );
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

    // 2. Write to Disk (L2) - Encrypted via cryptography
    try {
      if (_encryptionKey == null) return;

      // Encrypt using ChaCha20-Poly1305
      final secretBox = await _algorithm.encrypt(
        data,
        secretKey: _encryptionKey!,
      );

      if (_db != null && _db!.isOpen) {
        await _db!.insert('cache', {
          'key': key,
          'data': Uint8List.fromList(secretBox.cipherText),
          'nonce': base64Encode(secretBox.nonce),
          'mac': base64Encode(secretBox.mac.bytes),
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
      final macBase64 = row['mac'] as String;
      final timestamp = row['timestamp'] as int;

      // Check validity
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _kCacheValidity.inMilliseconds) {
        await _db!.delete('cache', where: 'key = ?', whereArgs: [key]);
        return null;
      }

      // Decrypt
      if (_rawKey != null) {
        try {
          final nonce = base64Decode(nonceBase64);
          final mac = base64Decode(macBase64);

          Uint8List decrypted;

          // Use isolate for large data to prevent UI jank
          if (encryptedBytes.length > _kAsyncDecryptThreshold) {
            decrypted = await compute(
              _decryptInIsolate,
              _DecryptParams(
                cipherText: encryptedBytes,
                nonce: nonce,
                mac: mac,
                rawKey: _rawKey!,
              ),
            );
          } else {
            // Small data - decrypt synchronously (faster for small blobs)
            final secretBox = SecretBox(
              encryptedBytes,
              nonce: nonce,
              mac: Mac(mac),
            );
            final result = await _algorithm.decrypt(
              secretBox,
              secretKey: _encryptionKey!,
            );
            decrypted = Uint8List.fromList(result);
          }

          // Populate L1
          _updateRamCache(key, decrypted);
          return decrypted;
        } catch (e) {
          _log.warning('Decryption failed', e);
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
    _isInitialized = false;
    _initCompleter = null;
  }
}
