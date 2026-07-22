import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/sync/sync_mutex.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FailingPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => null;

  @override
  Future<String?> getApplicationSupportPath() async => null;

  @override
  Future<String?> getApplicationCachePath() async => null;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  Directory? tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPlatform;
  });

  tearDown(() async {
    PathManager.resetForTests();
    PathProviderPlatform.instance = originalPlatform;
    final dir = tempDir;
    tempDir = null;
    try {
      if (dir != null) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // ignore: best-effort cleanup
    }
  });

  test('SyncMutex falls back and retries lock file after failure', () async {
    const key = 'sync_mutex_test';

    PathProviderPlatform.instance = _FailingPathProviderPlatform();
    PathManager.resetForTests();

    final v1 = await SyncMutex.instance.run(key, () async => 123);
    expect(v1, 123);

    tempDir = await Directory.systemTemp.createTemp('fleur_test_');
    final docs = await Directory(
      '${tempDir!.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir!.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir!.path}/cache',
    ).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
      cachePath: cache.path,
    );
    PathManager.resetForTests();

    final v2 = await SyncMutex.instance.run(key, () async => 456);
    expect(v2, 456);

    final stateDir = await PathManager.getStateDir();
    final lockFile = File(
      '${stateDir.path}${Platform.pathSeparator}mutex_$key.lock',
    );
    expect(await lockFile.exists(), isTrue);
  });

  test(
    'SyncMutex resolves a lock path again after the storage root changes',
    () async {
      const key = 'sync_mutex_path_refresh_test';
      final firstRoot = await Directory.systemTemp.createTemp(
        'fleur_mutex_first_',
      );
      final secondRoot = await Directory.systemTemp.createTemp(
        'fleur_mutex_second_',
      );
      addTearDown(() async {
        if (await firstRoot.exists()) await firstRoot.delete(recursive: true);
        if (await secondRoot.exists()) await secondRoot.delete(recursive: true);
      });

      Future<_FakePathProviderPlatform> configureRoot(Directory root) async {
        final docs = await Directory('${root.path}/documents').create();
        final support = await Directory('${root.path}/support').create();
        final cache = await Directory('${root.path}/cache').create();
        return _FakePathProviderPlatform(
          documentsPath: docs.path,
          supportPath: support.path,
          cachePath: cache.path,
        );
      }

      PathProviderPlatform.instance = await configureRoot(firstRoot);
      PathManager.resetForTests();
      await SyncMutex.instance.run(key, () async {});
      final firstStateDir = await PathManager.getStateDir();
      expect(
        await File(
          '${firstStateDir.path}${Platform.pathSeparator}mutex_$key.lock',
        ).exists(),
        isTrue,
      );

      PathProviderPlatform.instance = await configureRoot(secondRoot);
      PathManager.resetForTests();
      await SyncMutex.instance.run(key, () async {});
      final secondStateDir = await PathManager.getStateDir();
      expect(
        await File(
          '${secondStateDir.path}${Platform.pathSeparator}mutex_$key.lock',
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'SyncMutex removes a completed queue after the last waiter settles',
    () async {
      const key = 'sync_mutex_queue_cleanup_test';
      const failingKey = 'sync_mutex_failed_queue_cleanup_test';
      final started = Completer<void>();
      final release = Completer<void>();

      PathProviderPlatform.instance = _FailingPathProviderPlatform();
      PathManager.resetForTests();

      final first = SyncMutex.instance.run(key, () async {
        started.complete();
        await release.future;
      });
      await started.future;
      expect(SyncMutex.instance.hasPendingKey(key), isTrue);

      final second = SyncMutex.instance.run(key, () async {});
      release.complete();
      await Future.wait<void>([first, second]);
      await Future<void>.delayed(Duration.zero);

      expect(SyncMutex.instance.hasPendingKey(key), isFalse);

      await expectLater(
        SyncMutex.instance.run<void>(failingKey, () async {
          throw StateError('expected failure');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(SyncMutex.instance.hasPendingKey(failingKey), isFalse);
    },
  );
}
