import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import 'reader_settings.dart';
import '../../utils/path_manager.dart';

class ReaderSettingsStore {
  Future<ReaderSettings> load() async {
    try {
      var f = await _file();
      if (!await f.exists() && !PathManager.isMigrationComplete) {
        final legacy = await PathManager.legacyReaderSettingsFile();
        if (legacy != null) f = legacy;
      }
      if (!await f.exists()) return const ReaderSettings();
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        AppLogger.w(
          'Settings file ignored: unexpected JSON shape',
          tag: 'settings',
          context: const <String, Object?>{
            'file': 'reader_settings',
            'store': 'ReaderSettingsStore',
          },
        );
        return const ReaderSettings();
      }
      return ReaderSettings.fromJson(decoded.cast<String, Object?>());
    } catch (e, s) {
      AppLogger.w(
        'Settings load failed; using defaults',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'reader_settings',
          'store': 'ReaderSettingsStore',
        },
      );
      return const ReaderSettings();
    }
  }

  Future<void> save(ReaderSettings settings) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    return PathManager.readerSettingsFile();
  }
}
