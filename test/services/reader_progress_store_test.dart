import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reader/services/settings/reader_progress_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  late Directory tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flutter_reader_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
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
    expect(loaded.updatedAt.toIso8601String(), now.toIso8601String());
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
