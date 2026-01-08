import 'dart:async';
import 'dart:collection';

/// Global cache with automatic cleanup and size limits
class GlobalCache<K, V> {
  final int maxSize;
  final Duration? expireAfter;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();
  Timer? _cleanupTimer;

  GlobalCache({this.maxSize = 1000, this.expireAfter}) {
    if (expireAfter != null) {
      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _cleanupExpired(),
      );
    }
  }

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check expiration
    if (expireAfter != null &&
        DateTime.now().difference(entry.timestamp) > expireAfter!) {
      _cache.remove(key);
      return null;
    }

    // Move to end for LRU
    _cache.remove(key);
    _cache[key] = entry;

    return entry.value;
  }

  void put(K key, V value) {
    // Remove old value if exists
    _cache.remove(key);

    // Add new
    _cache[key] = _CacheEntry(value, DateTime.now());

    // Check size limit
    while (_cache.length > maxSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
  }

  void remove(K key) {
    _cache.remove(key);
  }

  /// Removes only old entries, keeping recent ones
  void trim({double ratio = 0.5}) {
    if (_cache.isEmpty) return;

    final targetSize = (_cache.length * ratio).round();
    // LinkedHashMap keeps insertion/access order, so first items are oldest
    while (_cache.length > targetSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
  }

  void clear() {
    _cache.clear();
  }

  int get length => _cache.length;

  void _cleanupExpired() {
    if (expireAfter == null) return;

    final now = DateTime.now();
    final keysToRemove = <K>[];

    for (final entry in _cache.entries) {
      if (now.difference(entry.value.timestamp) > expireAfter!) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}

class _CacheEntry<V> {
  final V value;
  final DateTime timestamp;

  _CacheEntry(this.value, this.timestamp);
}
