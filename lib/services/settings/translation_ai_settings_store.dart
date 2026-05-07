import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import '../../utils/path_manager.dart';
import 'translation_ai_settings.dart';

class TranslationAiSettingsStore {
  Future<TranslationAiSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return TranslationAiSettings.defaults();
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        AppLogger.w(
          'Settings file ignored: unexpected JSON shape',
          tag: 'settings',
          context: const <String, Object?>{
            'file': 'translation_ai_settings',
            'store': 'TranslationAiSettingsStore',
          },
        );
        return TranslationAiSettings.defaults();
      }
      final loaded = TranslationAiSettings.fromJson(
        decoded.cast<String, Object?>(),
      );
      final fixed = loaded.normalized();
      if (_jsonEquals(loaded.toJson(), fixed.toJson())) return loaded;
      try {
        await save(fixed);
      } catch (_) {
        // ignore: best-effort fixup
      }
      return fixed;
    } catch (e, s) {
      AppLogger.w(
        'Settings load failed; using defaults',
        tag: 'settings',
        error: _safeSettingsLoadError(e),
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'translation_ai_settings',
          'store': 'TranslationAiSettingsStore',
        },
      );
      return TranslationAiSettings.defaults();
    }
  }

  Future<void> save(TranslationAiSettings settings) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    return PathManager.translationAiSettingsFile();
  }

  bool _jsonEquals(Map<String, Object?> a, Map<String, Object?> b) {
    // Stable stringify compare; small payload so ok.
    return jsonEncode(a) == jsonEncode(b);
  }

  String _safeSettingsLoadError(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code != null) return 'FileSystemException(osErrorCode=$code)';
      return 'FileSystemException';
    }
    if (error is FormatException) return 'FormatException';
    return error.runtimeType.toString();
  }
}
