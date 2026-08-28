import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import '../network/user_agents.dart';
import '../persistence/durable_json_store.dart';
import 'app_settings.dart';
import '../../utils/path_manager.dart';

class AppSettingsStore {
  AppSettingsStore({DurableFileSystem fileSystem = const IoDurableFileSystem()})
    : _fileSystem = fileSystem;

  final DurableFileSystem _fileSystem;

  Future<AppSettings> load() async {
    try {
      final store = await _store();
      return await store.runExclusive(() => _loadLocked(store));
    } catch (e, s) {
      AppLogger.w(
        'Settings load failed; using defaults',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'app_settings',
          'store': 'AppSettingsStore',
        },
      );
      return AppSettings.defaults();
    }
  }

  Future<AppSettings> _loadLocked(DurableJsonStore<AppSettings> store) async {
    final snapshot = await store.read();
    if (snapshot == null) {
      return await _loadLegacy() ?? AppSettings.defaults();
    }
    if (snapshot.wasRecovered) {
      AppLogger.w(
        'Settings recovered from ${snapshot.source.name} snapshot',
        tag: 'settings',
        context: const <String, Object?>{
          'file': 'app_settings',
          'store': 'AppSettingsStore',
        },
      );
    }
    final loaded = snapshot.value;
    final migrated = _migrateIfNeeded(loaded);
    // Only persist when we actually loaded an on-disk settings file.
    if (jsonEncode(migrated.toJson()) != jsonEncode(loaded.toJson())) {
      try {
        await store.write(migrated);
      } catch (_) {
        // ignore: best-effort migration
      }
    }
    return migrated;
  }

  Future<AppSettings?> _loadLegacy() async {
    if (PathManager.isMigrationComplete) return null;
    final legacy = await PathManager.legacyAppSettingsFile();
    if (legacy == null) return null;
    return (await _storeFor(legacy).read())?.value;
  }

  Future<void> save(AppSettings settings) async {
    final store = await _store();
    await store.write(settings);
  }

  AppSettings _decode(Object? json) {
    if (json is! Map) {
      throw const FormatException('App settings JSON root is not an object');
    }
    return AppSettings.fromJson(json.cast<String, Object?>());
  }

  AppSettings _migrateIfNeeded(AppSettings cur) {
    var next = cur.normalized();
    // If user never customized UA (still legacy Windows default), use a
    // platform-aware default to avoid "Windows NT" on non-Windows builds.
    final platformDefault = UserAgents.webForCurrentPlatform();
    if (next.webUserAgent.trim() == UserAgents.web &&
        platformDefault.trim() != UserAgents.web) {
      next = next.copyWith(webUserAgent: platformDefault);
    }
    return next;
  }

  Future<DurableJsonStore<AppSettings>> _store() async {
    return _storeFor(await PathManager.appSettingsFile());
  }

  DurableJsonStore<AppSettings> _storeFor(File file) {
    return DurableJsonStore<AppSettings>(
      file: file,
      decode: _decode,
      encode: (settings) => settings.toJson(),
      fileSystem: _fileSystem,
    );
  }
}
