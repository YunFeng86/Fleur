import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/settings/reader_progress_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  late Directory tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_test_');
    final docs = await Directory(
      '${tempDir.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir.path}/cache',
    ).create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
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

  test('save and restore progress', () async {
    final store = ReaderProgressStore();
    final now = DateTime(2026, 2, 4, 10, 30, 0);
    final progress = ReaderProgress(
      articleId: 1,
      contentHash: 'hash-1',
      pixels: 120.5,
      progress: 0.42,
      updatedAt: now,
    );

    await store.saveProgress(progress);

    final reloaded = ReaderProgressStore();
    final loaded = await reloaded.getProgress(
      articleId: 1,
      contentHash: 'hash-1',
    );

    expect(loaded, isNotNull);
    expect(loaded!.pixels, 120.5);
    expect(loaded.progress, closeTo(0.42, 0.0001));
    expect(loaded.anchorIndex, isNull);
    expect(loaded.anchorFraction, isNull);
    expect(loaded.updatedAt.toIso8601String(), now.toIso8601String());
  });

  test('serializes optional anchor fields and accepts legacy json', () {
    final now = DateTime(2026, 2, 4, 10, 30, 0);
    final progress = ReaderProgress(
      articleId: 1,
      contentHash: 'hash-1',
      pixels: 120.5,
      progress: 0.42,
      updatedAt: now,
      anchorIndex: 3,
      anchorFraction: 0.65,
    );

    final json = progress.toJson();
    expect(json['anchorIndex'], 3);
    expect(json['anchorFraction'], 0.65);

    final restored = ReaderProgress.fromJson(json);
    expect(restored, isNotNull);
    expect(restored!.anchorIndex, 3);
    expect(restored.anchorFraction, closeTo(0.65, 0.0001));

    final legacy = Map<String, Object?>.from(json)
      ..remove('anchorIndex')
      ..remove('anchorFraction');
    final restoredLegacy = ReaderProgress.fromJson(legacy);
    expect(restoredLegacy, isNotNull);
    expect(restoredLegacy!.anchorIndex, isNull);
    expect(restoredLegacy.anchorFraction, isNull);
  });

  test('ReaderProgress.fromJson rejects non-finite required values', () {
    final now = DateTime(2026, 2, 4, 10, 30, 0).toIso8601String();
    final json = <String, Object?>{
      'articleId': 1,
      'contentHash': 'hash-1',
      'pixels': 120.5,
      'progress': 0.42,
      'updatedAt': now,
    };

    expect(
      ReaderProgress.fromJson(<String, Object?>{
        ...json,
        'articleId': double.infinity,
      }),
      isNull,
    );
    expect(
      ReaderProgress.fromJson(<String, Object?>{...json, 'pixels': double.nan}),
      isNull,
    );
    expect(
      ReaderProgress.fromJson(<String, Object?>{
        ...json,
        'progress': double.infinity,
      }),
      isNull,
    );
  });

  test('ReaderProgress.fromJson ignores non-finite optional anchors', () {
    final now = DateTime(2026, 2, 4, 10, 30, 0).toIso8601String();

    final restored = ReaderProgress.fromJson(<String, Object?>{
      'articleId': 1,
      'contentHash': 'hash-1',
      'pixels': 120.5,
      'progress': 0.42,
      'updatedAt': now,
      'anchorIndex': double.infinity,
      'anchorFraction': double.nan,
    });

    expect(restored, isNotNull);
    expect(restored!.anchorIndex, isNull);
    expect(restored.anchorFraction, isNull);
  });

  test('trim keeps latest entries', () async {
    final store = ReaderProgressStore();
    final base = DateTime(2026, 2, 4, 9, 0, 0);

    for (var i = 0; i < 245; i++) {
      await store.saveProgress(
        ReaderProgress(
          articleId: i,
          contentHash: 'hash-$i',
          pixels: i.toDouble(),
          progress: 0.1,
          updatedAt: base.add(Duration(minutes: i)),
        ),
      );
    }

    final reloaded = ReaderProgressStore();
    final removed = await reloaded.getProgress(
      articleId: 0,
      contentHash: 'hash-0',
    );
    final kept = await reloaded.getProgress(
      articleId: 244,
      contentHash: 'hash-244',
    );

    expect(removed, isNull, reason: '应裁剪掉最旧的进度记录');
    expect(kept, isNotNull, reason: '应保留最新的进度记录');
  });
}
