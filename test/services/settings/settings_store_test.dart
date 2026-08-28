import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/persistence/durable_json_store.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/services/settings/reader_settings_store.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  late Directory tempDir;
  late Directory supportDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_settings_test_');
    final docs = await Directory(
      '${tempDir.path}/documents',
    ).create(recursive: true);
    supportDir = await Directory(
      '${tempDir.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir.path}/cache',
    ).create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: supportDir.path,
      cachePath: cache.path,
    );
    PathManager.resetForTests();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPlatform;
  });

  Future<File> settingsFile(String name) async {
    final dir = await PathManager.getSettingsDir();
    return File('${dir.path}/$name');
  }

  test('app settings roundtrip through durable store', () async {
    final store = AppSettingsStore();
    await store.save(AppSettings.defaults().copyWith(filterKeywords: 'alpha'));

    final loaded = await AppSettingsStore().load();
    expect(loaded.filterKeywords, 'alpha');
  });

  test('reader settings roundtrip through durable store', () async {
    final store = ReaderSettingsStore();
    await store.save(const ReaderSettings().copyWith(fontSize: 21));

    final loaded = await ReaderSettingsStore().load();
    expect(loaded.fontSize, 21);
  });

  test('translation AI settings roundtrip through durable store', () async {
    final store = TranslationAiSettingsStore();
    await store.save(TranslationAiSettings.defaults().copyWith(tpmLimit: 1234));

    final loaded = await TranslationAiSettingsStore().load();
    expect(loaded.tpmLimit, 1234);
  });

  test('app settings recover from corrupt primary via backup', () async {
    final store = AppSettingsStore();
    await store.save(AppSettings.defaults().copyWith(filterKeywords: 'older'));
    await store.save(AppSettings.defaults().copyWith(filterKeywords: 'good'));
    final file = await settingsFile('app_settings.json');
    expect(await file.exists(), isTrue);
    expect(await File('${file.path}.bak').exists(), isTrue);

    await file.writeAsString('{ not valid json');

    // The backup holds the previous good snapshot.
    final loaded = await AppSettingsStore().load();
    expect(loaded.filterKeywords, 'older');
  });

  test('reader settings recover from corrupt primary via backup', () async {
    await ReaderSettingsStore().save(
      const ReaderSettings().copyWith(fontSize: 18),
    );
    await ReaderSettingsStore().save(
      const ReaderSettings().copyWith(fontSize: 19),
    );
    final file = await settingsFile('reader_settings.json');
    await file.writeAsString('garbage');

    final loaded = await ReaderSettingsStore().load();
    expect(loaded.fontSize, 18);
  });

  test(
    'translation AI settings recover from corrupt primary via backup',
    () async {
      await TranslationAiSettingsStore().save(
        TranslationAiSettings.defaults().copyWith(tpmLimit: 776),
      );
      await TranslationAiSettingsStore().save(
        TranslationAiSettings.defaults().copyWith(tpmLimit: 777),
      );
      final file = await settingsFile('translation_ai_settings.json');
      await file.writeAsString('garbage');

      final loaded = await TranslationAiSettingsStore().load();
      expect(loaded.tpmLimit, 776);
    },
  );

  test(
    'fully corrupted settings fall back to defaults without throwing',
    () async {
      await AppSettingsStore().save(
        AppSettings.defaults().copyWith(filterKeywords: 'lost'),
      );
      await AppSettingsStore().save(
        AppSettings.defaults().copyWith(filterKeywords: 'lost2'),
      );
      final file = await settingsFile('app_settings.json');
      await file.writeAsString('garbage');
      final bak = File('${file.path}.bak');
      if (await bak.exists()) {
        await bak.writeAsString('garbage');
      }
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) {
        await tmp.writeAsString('garbage');
      }

      final loaded = await AppSettingsStore().load();
      expect(loaded.filterKeywords, AppSettings.defaults().filterKeywords);
    },
  );

  test('rapid sequential saves keep the last value', () async {
    final store = AppSettingsStore();
    final futures = [
      for (var i = 0; i < 6; i++)
        store.save(AppSettings.defaults().copyWith(filterKeywords: 'v$i')),
    ];
    await Future.wait(futures);

    final loaded = await AppSettingsStore().load();
    expect(loaded.filterKeywords, 'v5');
  });

  test('failed write leaves the previous file intact', () async {
    final store = AppSettingsStore();
    await store.save(AppSettings.defaults().copyWith(filterKeywords: 'old'));

    final failing = AppSettingsStore(
      fileSystem: _FailTmpWriteFileSystem(failNextWrite: true),
    );
    await expectLater(
      failing.save(AppSettings.defaults().copyWith(filterKeywords: 'new')),
      throwsA(isA<Exception>()),
    );

    final reloaded = await AppSettingsStore().load();
    expect(reloaded.filterKeywords, 'old');
  });
}

/// Delegates to the real filesystem but fails the next `.tmp` write when
/// armed, simulating a crash mid-write.
class _FailTmpWriteFileSystem implements DurableFileSystem {
  _FailTmpWriteFileSystem({this.failNextWrite = false});

  final bool failNextWrite;

  @override
  Future<void> createParentDirectory(String filePath) async {
    await File(filePath).parent.create(recursive: true);
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<String> readAsString(String path) =>
      File(path).readAsString(encoding: utf8);

  @override
  Future<void> writeAsString(String path, String contents) async {
    if (failNextWrite && path.endsWith('.tmp')) {
      throw FileSystemException('simulated write failure', path);
    }
    await File(path).writeAsString(contents, encoding: utf8, flush: true);
  }

  @override
  Future<void> delete(String path) => File(path).delete();

  @override
  Future<void> move(String sourcePath, String destinationPath) =>
      File(sourcePath).rename(destinationPath);
}
