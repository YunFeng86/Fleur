import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import '../persistence/durable_json_store.dart';
import '../../utils/path_manager.dart';
import 'translation_ai_settings.dart';

class TranslationAiSettingsStore {
  TranslationAiSettingsStore({
    DurableFileSystem fileSystem = const IoDurableFileSystem(),
  }) : _fileSystem = fileSystem;

  final DurableFileSystem _fileSystem;

  Future<TranslationAiSettings> load() async {
    try {
      final store = await _store();
      return await store.runExclusive(() => _loadLocked(store));
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

  Future<TranslationAiSettings> _loadLocked(
    DurableJsonStore<TranslationAiSettings> store,
  ) async {
    final snapshot = await store.read();
    if (snapshot == null) return TranslationAiSettings.defaults();
    if (snapshot.wasRecovered) {
      AppLogger.w(
        'Settings recovered from ${snapshot.source.name} snapshot',
        tag: 'settings',
        context: const <String, Object?>{
          'file': 'translation_ai_settings',
          'store': 'TranslationAiSettingsStore',
        },
      );
    }
    final loaded = snapshot.value;
    final fixed = loaded.normalized();
    if (_jsonEquals(loaded.toJson(), fixed.toJson())) return loaded;
    try {
      await store.write(fixed);
    } catch (_) {
      // ignore: best-effort fixup
    }
    return fixed;
  }

  Future<void> save(TranslationAiSettings settings) async {
    final store = await _store();
    await store.write(settings);
  }

  TranslationAiSettings _decode(Object? json) {
    if (json is! Map) {
      throw const FormatException(
        'Translation AI settings JSON root is not an object',
      );
    }
    return TranslationAiSettings.fromJson(json.cast<String, Object?>());
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

  Future<DurableJsonStore<TranslationAiSettings>> _store() async {
    return _storeFor(await PathManager.translationAiSettingsFile());
  }

  DurableJsonStore<TranslationAiSettings> _storeFor(File file) {
    return DurableJsonStore<TranslationAiSettings>(
      file: file,
      decode: _decode,
      encode: (settings) => settings.toJson(),
      fileSystem: _fileSystem,
    );
  }
}
