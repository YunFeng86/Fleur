import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
    required String temporaryPath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath,
       _temporaryPath = temporaryPath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;
  final String _temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  Directory? tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
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
    final temporary = await Directory(
      '${tempDir!.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
    await AppLogger.resetForTests();
  });

  tearDown(() async {
    await AppLogger.resetForTests();
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

  test('OutboxStore save/load roundtrip', () async {
    final store = OutboxStore();
    const accountId = 'acc_roundtrip';

    final ts = DateTime.utc(2026, 2, 9, 12, 0, 0);
    await store.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: ts,
      ),
      OutboxAction(
        type: OutboxActionType.bookmark,
        remoteEntryId: 2,
        value: true,
        createdAt: ts,
      ),
    ]);

    final loaded = await store.load(accountId);
    expect(loaded, hasLength(2));
    expect(loaded[0].type, OutboxActionType.markRead);
    expect(loaded[1].type, OutboxActionType.bookmark);
  });

  test('OutboxStore recovers from .bak when primary is corrupted', () async {
    final store = OutboxStore();
    const accountId = 'acc_bak';

    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final bak = File('${primary.path}.bak');

    final ts = DateTime.utc(2026, 2, 10, 8, 30, 0);
    final expected = [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 42,
        value: true,
        createdAt: ts,
      ),
    ];

    await bak.writeAsString(
      jsonEncode(expected.map((a) => a.toJson()).toList(growable: false)),
      encoding: utf8,
    );
    await primary.writeAsString('[', encoding: utf8); // corrupted JSON

    final loaded = await store.load(accountId);
    expect(loaded, hasLength(1));
    expect(loaded.first.remoteEntryId, 42);

    final raw = await primary.readAsString(encoding: utf8);
    final decoded = jsonDecode(raw);
    expect(decoded, isA<List>());
  });

  test('OutboxStore recovers from .tmp when primary is corrupted', () async {
    final store = OutboxStore();
    const accountId = 'acc_tmp';

    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final tmp = File('${primary.path}.tmp');

    final ts = DateTime.utc(2026, 2, 10, 9, 0, 0);
    final expected = [
      OutboxAction(
        type: OutboxActionType.bookmark,
        remoteEntryId: 7,
        value: true,
        createdAt: ts,
      ),
    ];

    await tmp.writeAsString(
      jsonEncode(expected.map((a) => a.toJson()).toList(growable: false)),
      encoding: utf8,
    );
    await primary.writeAsString('[', encoding: utf8); // corrupted JSON

    final loaded = await store.load(accountId);
    expect(loaded, hasLength(1));
    expect(loaded.first.remoteEntryId, 7);
    expect(await tmp.exists(), isFalse);
  });

  test('OutboxStore logs when all recovery files are damaged', () async {
    await AppLogger.ensureInitialized();
    final store = OutboxStore();
    const accountId = 'acc_damaged';

    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final tmp = File('${primary.path}.tmp');
    final bak = File('${primary.path}.bak');

    await primary.writeAsString('[', encoding: utf8);
    await tmp.writeAsString('{', encoding: utf8);
    await bak.writeAsString('"not a list"', encoding: utf8);

    final loaded = await store.load(accountId);
    final contents = await _readActiveLog();

    expect(loaded, isEmpty);
    expect(contents, contains('[W] [outbox] Outbox recovery failed'));
    expect(contents, contains('accountId=$accountId'));
    expect(contents, contains('operation=recover'));
    expect(contents, contains('primaryExists=true'));
    expect(contents, contains('tmpExists=true'));
    expect(contents, contains('bakExists=true'));
  });

  test('OutboxStore logs malformed entries without action details', () async {
    await AppLogger.ensureInitialized();
    final store = OutboxStore();
    const accountId = 'acc_malformed';

    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final ts = DateTime.utc(2026, 2, 10, 10, 0, 0);
    await primary.writeAsString(
      jsonEncode([
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 42,
          value: true,
          createdAt: ts,
        ).toJson(),
        {
          'type': 'unknown',
          'feedUrl': 'https://feeds.example.com/rss?token=secret',
          'categoryTitle': 'Private Category',
          'createdAt': ts.toIso8601String(),
        },
      ]),
      encoding: utf8,
    );

    final loaded = await store.load(accountId);
    final contents = await _readActiveLog();

    expect(loaded, hasLength(1));
    expect(contents, contains('[W] [outbox] Outbox malformed entries skipped'));
    expect(contents, contains('accountId=$accountId'));
    expect(contents, contains('operation=load'));
    expect(contents, contains('malformedEntryCount=1'));
    expect(contents, isNot(contains('token=secret')));
    expect(contents, isNot(contains('Private Category')));
  });

  test(
    'OutboxStore logs failed writes without feed or category text',
    () async {
      await AppLogger.ensureInitialized();
      final store = OutboxStore();
      const accountId = 'acc_unwritable';

      final stateDir = await PathManager.getStateDir();
      final primaryPath =
          '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json';
      await Directory(primaryPath).create(recursive: true);
      await Directory('$primaryPath.tmp').create(recursive: true);

      await store.save(accountId, [
        OutboxAction(
          type: OutboxActionType.markAllRead,
          feedUrl: 'https://feeds.example.com/rss?token=secret',
          categoryTitle: 'Private Category',
          createdAt: DateTime.utc(2026, 2, 10, 11, 0, 0),
        ),
      ]);
      final contents = await _readActiveLog();

      expect(contents, contains('[W] [outbox] Outbox temp write failed'));
      expect(contents, contains('[W] [outbox] Outbox direct write failed'));
      expect(contents, contains('accountId=$accountId'));
      expect(contents, contains('actionCount=1'));
      expect(contents, contains('compactedCount=1'));
      expect(contents, isNot(contains('token=secret')));
      expect(contents, isNot(contains('Private Category')));
    },
  );
}

Future<String> _readActiveLog() async {
  final logFile = await AppLogger.getActiveLogFile();
  await AppLogger.resetForTests();
  return logFile!.readAsString();
}
