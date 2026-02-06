import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../utils/path_utils.dart';

class FaviconCacheEntry {
  const FaviconCacheEntry({required this.fetchedAt, required this.iconUrl});

  final DateTime fetchedAt;

  /// Resolved favicon URL. When null, it represents a cached miss.
  final String? iconUrl;

  bool isExpired({required Duration ttl}) {
    return DateTime.now().difference(fetchedAt) > ttl;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'fetchedAt': fetchedAt.toIso8601String(),
    'iconUrl': iconUrl,
  };

  static FaviconCacheEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fetchedAtRaw = raw['fetchedAt'];
    if (fetchedAtRaw is! String) return null;
    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    if (fetchedAt == null) return null;
    final iconUrlRaw = raw['iconUrl'];
    return FaviconCacheEntry(
      fetchedAt: fetchedAt,
      iconUrl: iconUrlRaw is String ? iconUrlRaw : null,
    );
  }
}

/// A tiny persistent cache for favicon resolution results.
///
/// Stores host -> { fetchedAt, iconUrl } in app data directory.
/// This intentionally caches misses (iconUrl == null) to avoid hammering sites.
class FaviconStore {
  static const String _fileName = 'favicons.json';
  static const int _maxEntries = 500;
  static const Duration _maxAge = Duration(days: 90);

  bool _loaded = false;
  Map<String, FaviconCacheEntry> _mem = <String, FaviconCacheEntry>{};

  Future<FaviconCacheEntry?> get(String host) {
    return _serial(() async {
      final map = await _ensureLoaded();
      return map[host];
    });
  }

  Future<void> set(String host, FaviconCacheEntry entry) {
    return _serial(() async {
      final map = await _ensureLoaded();
      map[host] = entry;
      _prune(map);
      await _writeAll(map);
    });
  }

  Future<void> remove(String host) {
    return _serial(() async {
      final map = await _ensureLoaded();
      if (!map.containsKey(host)) return;
      map.remove(host);
      await _writeAll(map);
    });
  }

  // Simple async mutex for file access.
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() fn) {
    final next = _tail.then((_) => fn());
    _tail = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<File> _file() async {
    final dir = await PathUtils.getAppDataDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<Map<String, FaviconCacheEntry>> _ensureLoaded() async {
    if (_loaded) return _mem;
    _mem = await _readAllFromFile();

    // Prune on load as well, so old app upgrades don't keep carrying a huge file
    // around forever. This is best-effort and should not block app startup.
    final before = _mem.length;
    _prune(_mem);
    if (_mem.length != before) {
      await _writeAll(_mem);
    }

    _loaded = true;
    return _mem;
  }

  Future<Map<String, FaviconCacheEntry>> _readAllFromFile() async {
    try {
      final f = await _file();
      if (!await f.exists()) return <String, FaviconCacheEntry>{};
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return <String, FaviconCacheEntry>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, FaviconCacheEntry>{};

      final out = <String, FaviconCacheEntry>{};
      for (final entry in decoded.entries) {
        final host = entry.key;
        if (host is! String) continue;
        final parsed = FaviconCacheEntry.fromJson(entry.value);
        if (parsed == null) continue;
        out[host] = parsed;
      }
      return out;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('favicon store read failed: $e');
      }
      return <String, FaviconCacheEntry>{};
    }
  }

  Future<void> _writeAll(Map<String, FaviconCacheEntry> map) async {
    try {
      final f = await _file();
      final encoded = <String, Object?>{};
      for (final e in map.entries) {
        encoded[e.key] = e.value.toJson();
      }
      await f.writeAsString(jsonEncode(encoded));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('favicon store write failed: $e');
      }
    }
  }

  void _prune(Map<String, FaviconCacheEntry> map) {
    if (map.isEmpty) return;

    // Best-effort cleanup to keep the file size bounded.
    final now = DateTime.now();
    map.removeWhere((_, v) => now.difference(v.fetchedAt) > _maxAge);

    if (map.length <= _maxEntries) return;

    final entries = map.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));

    final overflow = map.length - _maxEntries;
    for (var i = 0; i < overflow; i++) {
      map.remove(entries[i].key);
    }
  }
}
