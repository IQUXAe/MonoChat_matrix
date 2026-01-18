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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
      'secure_cache_key_v2_sodium'; // New key ver
  static const String _kDbName = 'secure_cache_v2_sodium.db'; // New db
  static const int _kRamCacheSize = 50; // Max items in RAM
  static const Duration _kCacheValidity = Duration(days: 30); // Auto-expire

  // ===========================================================================
  // STATE
  // ===========================================================================

  Database? _db;
  Sodium? _sodium;
  SecureKey? _encryptionKey;
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

      // 2. Initialize FFI for desktop if needed
      if (Platform.isWindows || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // 3. Load or Create Encryption Key
      await _setupEncryption();

      // 4. Open Database
      await _openDatabase();

      _isInitialized = true;
      _log.info('Secure Cache initialized successfully.');
    } catch (e, s) {
      _log.severe('Failed to init secure cache.', e, s);
      try {
        await nuke();
      } catch (_) {}
    }
  }

  Future<void> _setupEncryption() async {
    const storage = FlutterSecureStorage();

    try {
      String? keyBase64;
      try {
        keyBase64 = await storage.read(key: _kKeyStorageName);
      } catch (e) {
        _log.warning('Secure storge read failed (L2 Cache)', e);
        // Proceed to generate ephemeral key or try to overwrite if getting explicit error
      }

      if (keyBase64 == null) {
        _log.info('Generating new secure cache key (Sodium)...');
        // Generate secure random key using Sodium
        final keyBytes = _sodium!.randombytes.buf(
          _sodium!.crypto.secretBox.keyBytes,
        );
        final key = _sodium!.secureCopy(keyBytes);

        try {
          await storage.write(
            key: _kKeyStorageName,
            value: base64Encode(keyBytes),
          );
        } catch (e) {
          _log.warning(
            'Secure storage write failed (L2 Cache). Key is ephemeral.',
            e,
          );
        }
        _encryptionKey = key;
      } else {
        try {
          final keyBytes = base64Decode(keyBase64);
          if (keyBytes.length != _sodium!.crypto.secretBox.keyBytes) {
            throw Exception('Invalid key length');
          }
          _encryptionKey = _sodium!.secureCopy(Uint8List.fromList(keyBytes));
        } catch (e) {
          _log.warning(
            'Invalid key format in storage, regenerating temporary key.',
            e,
          );
          final keyBytes = _sodium!.randombytes.buf(
            _sodium!.crypto.secretBox.keyBytes,
          );
          _encryptionKey = _sodium!.secureCopy(keyBytes);
        }
      }
    } catch (e) {
      _log.severe(
        'Secure storage access failed (Keychain locked?). '
        'Using temporary in-memory key for this session. '
        'L2 Cache will NOT survive app restart.',
        e,
      );
      // Fallback: Use an in-memory key via Sodium
      final keyBytes = _sodium!.randombytes.buf(
        _sodium!.crypto.secretBox.keyBytes,
      );
      _encryptionKey = _sodium!.secureCopy(keyBytes);
    }
  }

  Future<void> _openDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _kDbName);

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cache (
              key TEXT PRIMARY KEY,
              data BLOB,
              nonce TEXT,
              timestamp INTEGER
            )
          ''');
          await db.execute('CREATE INDEX idx_timestamp ON cache (timestamp)');
        },
      ),
    );
  }

  // ===========================================================================
  // OPERATIONS
  // ===========================================================================

  /// Puts data into the cache (L1 + L2).
  Future<void> put(String key, Uint8List data) async {
    if (!_isInitialized) await init();

    // 1. Write to RAM (L1)
    _updateRamCache(key, data);

    // 2. Write to Disk (L2) - Encrypted via Sodium
    try {
      if (_encryptionKey == null || _sodium == null) {
        _log.warning(
          'Skipping L2 cache write: Encryption key not initialized.',
        );
        return;
      }

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
        }, conflictAlgorithm: ConflictAlgorithm.replace);
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
      try {
        if (_db != null && _db!.isOpen) {
          await _db!.delete('cache', where: 'key = ?', whereArgs: [key]);
        }
      } catch (_) {}
      return null;
    }
  }

  // ===========================================================================
  // MAINTENANCE
  // ===========================================================================

  Future<int> getCacheSize() async {
    if (!_isInitialized) return 0;
    try {
      int size = 0;
      // 1. DB Size (approximate from data length)
      if (_db != null && _db!.isOpen) {
        final result = await _db!.rawQuery(
          'SELECT SUM(length(data)) as size FROM cache',
        );
        if (result.isNotEmpty && result.first['size'] != null) {
          size += result.first['size'] as int;
        }
      }
      // 2. RAM Cache
      // Estimate ram size?
      for (var data in _ramCache.values) {
        size += data.length;
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  void _updateRamCache(String key, Uint8List data) {
    if (_ramCache.containsKey(key)) {
      _ramCache.remove(key);
    }
    _ramCache[key] = data;

    // Enforce size limit
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

    // Clear RAM
    _ramCache.clear();
    _encryptionKey?.dispose(); // Dispose Sodium key
    _encryptionKey = null;

    try {
      // Close DB
      if (_db != null && _db!.isOpen) {
        await _db!.close();
      }

      // Delete DB File
      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, _kDbName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _log.severe('Error deleting DB file', e);
    }

    // Delete Key
    try {
      await _storage.delete(key: _kKeyStorageName);
    } catch (e) {
      _log.warning(
        'Failed to delete secure key (may not exist or keychain locked)',
        e,
      );
    }

    _db = null;
    _sodium = null;
    _isInitialized = false;
  }
}
