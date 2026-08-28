import 'dart:io';

import '../logging/app_logger.dart';
import '../persistence/durable_json_store.dart';
import 'reader_settings.dart';
import '../../utils/path_manager.dart';

class ReaderSettingsStore {
  ReaderSettingsStore({
    DurableFileSystem fileSystem = const IoDurableFileSystem(),
  }) : _fileSystem = fileSystem;

  final DurableFileSystem _fileSystem;

  Future<ReaderSettings> load() async {
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
          'file': 'reader_settings',
          'store': 'ReaderSettingsStore',
        },
      );
      return const ReaderSettings();
    }
  }

  Future<ReaderSettings> _loadLocked(
    DurableJsonStore<ReaderSettings> store,
  ) async {
    final snapshot = await store.read();
    if (snapshot == null) {
      return await _loadLegacy() ?? const ReaderSettings();
    }
    if (snapshot.wasRecovered) {
      AppLogger.w(
        'Settings recovered from ${snapshot.source.name} snapshot',
        tag: 'settings',
        context: const <String, Object?>{
          'file': 'reader_settings',
          'store': 'ReaderSettingsStore',
        },
      );
    }
    return snapshot.value;
  }

  Future<ReaderSettings?> _loadLegacy() async {
    if (PathManager.isMigrationComplete) return null;
    final legacy = await PathManager.legacyReaderSettingsFile();
    if (legacy == null) return null;
    return (await _storeFor(legacy).read())?.value;
  }

  Future<void> save(ReaderSettings settings) async {
    final store = await _store();
    await store.write(settings);
  }

  ReaderSettings _decode(Object? json) {
    if (json is! Map) {
      throw const FormatException('Reader settings JSON root is not an object');
    }
    return ReaderSettings.fromJson(json.cast<String, Object?>());
  }

  Future<DurableJsonStore<ReaderSettings>> _store() async {
    return _storeFor(await PathManager.readerSettingsFile());
  }

  DurableJsonStore<ReaderSettings> _storeFor(File file) {
    return DurableJsonStore<ReaderSettings>(
      file: file,
      decode: _decode,
      encode: (settings) => settings.toJson(),
      fileSystem: _fileSystem,
    );
  }
}
