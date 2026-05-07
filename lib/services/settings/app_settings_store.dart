import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';
import '../logging/app_logger.dart';
import '../network/user_agents.dart';
import '../../utils/path_manager.dart';

class AppSettingsStore {
  Future<AppSettings> load() async {
    try {
      var f = await _file();
      if (!await f.exists() && !PathManager.isMigrationComplete) {
        final legacy = await PathManager.legacyAppSettingsFile();
        if (legacy != null) f = legacy;
      }
      final exists = await f.exists();
      if (!exists) return AppSettings.defaults();
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        AppLogger.w(
          'Settings file ignored: unexpected JSON shape',
          tag: 'settings',
          context: const <String, Object?>{
            'file': 'app_settings',
            'store': 'AppSettingsStore',
          },
        );
        return AppSettings.defaults();
      }

      final loaded = AppSettings.fromJson(decoded.cast<String, Object?>());
      final migrated = _migrateIfNeeded(loaded);
      // Only persist when we actually loaded an on-disk settings file.
      if (jsonEncode(migrated.toJson()) != jsonEncode(loaded.toJson())) {
        try {
          await save(migrated);
        } catch (_) {
          // ignore: best-effort migration
        }
      }
      return migrated;
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

  Future<void> save(AppSettings settings) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    return PathManager.appSettingsFile();
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
}
