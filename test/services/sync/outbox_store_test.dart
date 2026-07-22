@Tags(['global_logger'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/persistence/durable_json_store.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test_utils/fake_path_provider_platform.dart';

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
    PathProviderPlatform.instance = FakePathProviderPlatform(
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

  test(
    'OutboxStore roundtrips string entry keys and compacts by stream',
    () async {
      final store = OutboxStore();
      const accountId = 'acc_string_keys';
      final ts = DateTime.utc(2026, 2, 9, 12, 0, 0);

      await store.save(accountId, [
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryKey: 'tag:google.com,2005:reader/item/a',
          value: true,
          createdAt: ts,
        ),
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryKey: 'tag:google.com,2005:reader/item/a',
          value: false,
          createdAt: ts.add(const Duration(seconds: 1)),
        ),
        OutboxAction(
          type: OutboxActionType.markAllRead,
          streamId: 'user/-/label/News',
          value: true,
          createdAt: ts,
        ),
        OutboxAction(
          type: OutboxActionType.markAllRead,
          streamId: 'user/-/label/News',
          value: true,
          createdAt: ts.add(const Duration(seconds: 2)),
        ),
      ]);

      final loaded = await store.load(accountId);
      expect(loaded, hasLength(2));
      expect(loaded[0].type, OutboxActionType.markRead);
      expect(loaded[0].remoteEntryId, isNull);
      expect(loaded[0].remoteEntryKey, 'tag:google.com,2005:reader/item/a');
      expect(loaded[0].value, isFalse);
      expect(loaded[1].type, OutboxActionType.markAllRead);
      expect(loaded[1].streamId, 'user/-/label/News');
    },
  );

  test(
    'OutboxStore compacts numeric remote entry IDs to the last intent',
    () async {
      final store = OutboxStore();
      const accountId = 'acc_numeric_compaction';
      final ts = DateTime.utc(2026, 2, 9, 12);

      await store.save(accountId, <OutboxAction>[
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 42,
          value: true,
          createdAt: ts,
        ),
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 42,
          value: false,
          createdAt: ts.add(const Duration(seconds: 1)),
        ),
        OutboxAction(
          type: OutboxActionType.bookmark,
          remoteEntryId: 42,
          value: true,
          createdAt: ts,
        ),
        OutboxAction(
          type: OutboxActionType.bookmark,
          remoteEntryId: 42,
          value: false,
          createdAt: ts.add(const Duration(seconds: 2)),
        ),
      ]);

      final loaded = await store.load(accountId);
      expect(loaded, hasLength(2));
      expect(
        loaded
            .singleWhere((action) => action.type == OutboxActionType.markRead)
            .value,
        isFalse,
      );
      expect(
        loaded
            .singleWhere((action) => action.type == OutboxActionType.bookmark)
            .value,
        isFalse,
      );
    },
  );

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
    final backupDecoded = jsonDecode(await bak.readAsString());
    expect(backupDecoded, isA<List>());
    final backupAction = (backupDecoded as List<Object?>).single;
    expect(
      OutboxAction.fromJson(
        (backupAction as Map).cast<String, Object?>(),
      ).remoteEntryId,
      42,
    );
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

  test(
    'OutboxStore skips a malformed tmp and recovers the valid backup',
    () async {
      final store = OutboxStore();
      const accountId = 'acc_malformed_tmp';
      final stateDir = await PathManager.getStateDir();
      final primary = File(
        '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
      );
      final tmp = File('${primary.path}.tmp');
      final bak = File('${primary.path}.bak');
      final action = OutboxAction(
        type: OutboxActionType.bookmark,
        remoteEntryId: 73,
        value: true,
        createdAt: DateTime.utc(2026, 2, 10, 9, 15),
      );
      final backupRaw = jsonEncode(<Object?>[action.toJson()]);

      await primary.writeAsString('[', encoding: utf8);
      await tmp.writeAsString(
        jsonEncode(<Object?>[
          <String, Object?>{
            'type': 'unknown',
            'createdAt': DateTime.utc(2026, 2, 10, 9, 16).toIso8601String(),
          },
        ]),
        encoding: utf8,
      );
      await bak.writeAsString(backupRaw, encoding: utf8);

      final loaded = await store.load(accountId);

      expect(loaded, hasLength(1));
      expect(loaded.single.remoteEntryId, 73);
      expect(await primary.readAsString(), backupRaw);
      expect(await bak.readAsString(), backupRaw);
      expect(await tmp.exists(), isFalse);
    },
  );

  test(
    'OutboxStore fails closed when all recovery files are damaged',
    () async {
      await AppLogger.ensureInitialized();
      final store = OutboxStore();
      const accountId = 'acc_damaged';

      final stateDir = await PathManager.getStateDir();
      final primary = File(
        '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
      );
      final tmp = File('${primary.path}.tmp');
      final bak = File('${primary.path}.bak');

      await primary.writeAsString(
        '[{"feedUrl":"https://feeds.example.com/rss?token=secret"',
        encoding: utf8,
      );
      await tmp.writeAsString(
        '{"categoryTitle":"Private Category"',
        encoding: utf8,
      );
      await bak.writeAsString('"not a list"', encoding: utf8);

      final primaryRaw = await primary.readAsString();
      final temporaryRaw = await tmp.readAsString();
      final backupRaw = await bak.readAsString();
      await expectLater(
        store.load(accountId),
        throwsA(isA<OutboxReadException>()),
      );
      await expectLater(
        store.enqueue(
          accountId,
          OutboxAction(
            type: OutboxActionType.markRead,
            remoteEntryId: 42,
            value: true,
            createdAt: DateTime.utc(2026, 2, 10, 9, 30),
          ),
        ),
        throwsA(isA<OutboxReadException>()),
      );
      final contents = await _readActiveLog();

      expect(await primary.readAsString(), primaryRaw);
      expect(await tmp.readAsString(), temporaryRaw);
      expect(await bak.readAsString(), backupRaw);
      expect(contents, contains('[W] [outbox] Outbox recovery failed'));
      expect(contents, contains('accountId=$accountId'));
      expect(contents, contains('operation=recover'));
      expect(contents, contains('primaryExists=true'));
      expect(contents, contains('tmpExists=true'));
      expect(contents, contains('bakExists=true'));
      expect(contents, isNot(contains('token=secret')));
      expect(contents, isNot(contains('Private Category')));
      expect(contents, isNot(contains(stateDir.path)));
    },
  );

  test('OutboxStore fails closed on malformed action entries', () async {
    await AppLogger.ensureInitialized();
    final store = OutboxStore();
    const accountId = 'acc_malformed';

    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final ts = DateTime.utc(2026, 2, 10, 10, 0, 0);
    final raw = jsonEncode([
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
    ]);
    await primary.writeAsString(raw, encoding: utf8);

    await expectLater(
      store.load(accountId),
      throwsA(isA<OutboxReadException>()),
    );
    final contents = await _readActiveLog();

    expect(await primary.readAsString(), raw);
    expect(
      contents,
      contains('[W] [outbox] Outbox malformed entries detected'),
    );
    expect(contents, contains('accountId=$accountId'));
    expect(contents, contains('operation=load'));
    expect(contents, contains('malformedEntryCount=1'));
    expect(contents, isNot(contains('token=secret')));
    expect(contents, isNot(contains('Private Category')));
  });

  test(
    'OutboxStore fails closed and retains tmp when recovery cannot commit',
    () async {
      final store = OutboxStore();
      const accountId = 'acc_tmp_recovery_write_failure';
      final stateDir = await PathManager.getStateDir();
      final primaryPath =
          '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json';
      final primaryDirectory = await Directory(primaryPath).create();
      final tmp = File('$primaryPath.tmp');
      final action = OutboxAction(
        type: OutboxActionType.bookmark,
        remoteEntryId: 7,
        value: true,
        createdAt: DateTime.utc(2026, 2, 10, 10, 30),
      );
      final raw = jsonEncode(<Object?>[action.toJson()]);
      await tmp.writeAsString(raw, encoding: utf8);

      await expectLater(
        store.load(accountId),
        throwsA(isA<OutboxReadException>()),
      );

      expect(await primaryDirectory.exists(), isTrue);
      expect(await tmp.exists(), isTrue);
      expect(await tmp.readAsString(), raw);
    },
  );

  test('OutboxStore preserves the primary when temp staging fails', () async {
    await AppLogger.ensureInitialized();
    final store = OutboxStore();
    const accountId = 'acc_unwritable';

    final stateDir = await PathManager.getStateDir();
    final primaryPath =
        '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json';
    final primary = File(primaryPath);
    final originalAction = OutboxAction(
      type: OutboxActionType.markRead,
      remoteEntryId: 41,
      value: true,
      createdAt: DateTime.utc(2026, 2, 10, 10, 45),
    );
    await store.save(accountId, <OutboxAction>[originalAction]);
    final originalContents = await primary.readAsString();
    await Directory('$primaryPath.tmp').create(recursive: true);

    await expectLater(
      store.enqueue(
        accountId,
        OutboxAction(
          type: OutboxActionType.markAllRead,
          feedUrl: 'https://feeds.example.com/rss?token=secret',
          categoryTitle: 'Private Category',
          createdAt: DateTime.utc(2026, 2, 10, 11, 0, 0),
        ),
      ),
      throwsA(
        isA<DurableJsonWriteException>().having(
          (error) => error.stage,
          'stage',
          DurableJsonWriteStage.temporaryWrite,
        ),
      ),
    );
    final contents = await _readActiveLog();

    expect(await primary.readAsString(), originalContents);
    final loaded = await store.load(accountId);
    expect(loaded, hasLength(1));
    expect(loaded.single.remoteEntryId, 41);
    expect(contents, contains('[W] [outbox] Outbox write failed'));
    expect(
      contents,
      contains('DurableJsonWriteException(stage=temporaryWrite)'),
    );
    expect(contents, contains('accountId=$accountId'));
    expect(contents, contains('actionCount=2'));
    expect(contents, contains('compactedCount=2'));
    expect(contents, isNot(contains('token=secret')));
    expect(contents, isNot(contains('Private Category')));
    expect(contents, isNot(contains(stateDir.path)));
  });

  test('OutboxStore preserves primary when backup rotation fails', () async {
    final store = OutboxStore(fileSystem: _BackupMoveFailingFileSystem());
    const accountId = 'acc_backup_failure';
    final first = OutboxAction(
      type: OutboxActionType.markRead,
      remoteEntryId: 91,
      value: true,
      createdAt: DateTime.utc(2026, 2, 10, 11, 30),
    );
    final second = OutboxAction(
      type: OutboxActionType.markRead,
      remoteEntryId: 92,
      value: true,
      createdAt: DateTime.utc(2026, 2, 10, 11, 31),
    );
    await store.save(accountId, <OutboxAction>[first]);
    final stateDir = await PathManager.getStateDir();
    final primary = File(
      '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json',
    );
    final originalContents = await primary.readAsString();

    await expectLater(
      store.save(accountId, <OutboxAction>[second]),
      throwsA(
        isA<DurableJsonWriteException>().having(
          (error) => error.stage,
          'stage',
          DurableJsonWriteStage.backup,
        ),
      ),
    );

    expect(await primary.readAsString(), originalContents);
    expect(await File('${primary.path}.tmp').exists(), isFalse);
    final loaded = await store.load(accountId);
    expect(loaded, hasLength(1));
    expect(loaded.single.remoteEntryId, 91);
  });
}

Future<String> _readActiveLog() async {
  final logFile = await AppLogger.getActiveLogFile();
  await AppLogger.resetForTests();
  return logFile!.readAsString();
}

class _BackupMoveFailingFileSystem implements DurableFileSystem {
  final IoDurableFileSystem _delegate = const IoDurableFileSystem();

  @override
  Future<void> createParentDirectory(String filePath) {
    return _delegate.createParentDirectory(filePath);
  }

  @override
  Future<void> delete(String path) => _delegate.delete(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<void> move(String sourcePath, String destinationPath) {
    if (destinationPath.endsWith('.bak')) {
      throw FileSystemException('Injected backup move failure');
    }
    return _delegate.move(sourcePath, destinationPath);
  }

  @override
  Future<String> readAsString(String path) => _delegate.readAsString(path);

  @override
  Future<void> writeAsString(String path, String contents) {
    return _delegate.writeAsString(path, contents);
  }
}
