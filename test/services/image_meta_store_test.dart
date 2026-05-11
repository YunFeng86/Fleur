import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/cache/image_meta_store.dart';
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

  test('save and load image meta', () async {
    final store = ImageMetaStore();
    final now = DateTime(2026, 2, 4, 12, 0, 0);
    await store.saveMany({
      'https://example.com/a.png': ImageMeta(
        width: 640,
        height: 480,
        updatedAt: now,
      ),
    });

    final reloaded = ImageMetaStore();
    final meta = await reloaded.get('https://example.com/a.png');

    expect(meta, isNotNull);
    expect(meta!.width, 640);
    expect(meta.height, 480);
    expect(meta.updatedAt.toIso8601String(), now.toIso8601String());
  });

  test('ImageMeta.fromJson rejects non-finite dimensions', () {
    final now = DateTime(2026, 2, 4, 12, 0, 0).toIso8601String();

    expect(
      ImageMeta.fromJson({
        'width': double.nan,
        'height': 480,
        'updatedAt': now,
      }),
      isNull,
    );
    expect(
      ImageMeta.fromJson({
        'width': 640,
        'height': double.infinity,
        'updatedAt': now,
      }),
      isNull,
    );
  });

  test('clear removes cached data', () async {
    final store = ImageMetaStore();
    await store.saveMany({
      'https://example.com/b.png': ImageMeta(
        width: 100,
        height: 200,
        updatedAt: DateTime.now(),
      ),
    });

    await store.clear();
    final meta = await store.get('https://example.com/b.png');
    expect(meta, isNull);
  });
}
