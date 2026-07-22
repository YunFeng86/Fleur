import 'dart:async';
import 'dart:io';

import 'package:fleur/services/sync/outbox/outbox_delivery.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:flutter_test/flutter_test.dart';
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
    tempDir = await Directory.systemTemp.createTemp('fleur_outbox_delivery_');
    final documents = await Directory(
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
      documentsPath: documents.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
  });

  tearDown(() async {
    PathManager.resetForTests();
    PathProviderPlatform.instance = originalPlatform;
    final dir = tempDir;
    tempDir = null;
    if (dir != null) await dir.delete(recursive: true);
  });

  test(
    'flush preserves a newer intent enqueued during remote delivery',
    () async {
      const accountId = 'delivery-race';
      final store = OutboxStore();
      final started = Completer<void>();
      final release = Completer<void>();
      final original = OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 42,
        value: true,
        createdAt: DateTime.utc(2026, 7, 21, 10),
      );
      final newer = OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 42,
        value: false,
        createdAt: DateTime.utc(2026, 7, 21, 10, 0, 1),
      );
      await store.enqueue(accountId, original);

      final flush = OutboxDelivery(store).flush(
        accountId: accountId,
        apply: (action) async {
          started.complete();
          await release.future;
          return true;
        },
      );
      await started.future;

      await store.enqueue(accountId, newer);
      release.complete();
      await flush;

      final pending = await store.load(accountId);
      expect(pending, hasLength(1));
      expect(pending.single.createdAt, newer.createdAt);
      expect(pending.single.value, isFalse);
    },
  );

  test('flush acknowledges successes and retains rejected actions', () async {
    const accountId = 'delivery-partial';
    final store = OutboxStore();
    final delivered = OutboxAction(
      type: OutboxActionType.markRead,
      remoteEntryId: 1,
      value: true,
      createdAt: DateTime.utc(2026, 7, 21, 10),
    );
    final rejected = OutboxAction(
      type: OutboxActionType.bookmark,
      remoteEntryId: 2,
      value: true,
      createdAt: DateTime.utc(2026, 7, 21, 10, 0, 1),
    );
    await store.save(accountId, <OutboxAction>[delivered, rejected]);

    await OutboxDelivery(store).flush(
      accountId: accountId,
      apply: (action) async => action.remoteEntryId == 1,
    );

    final pending = await store.load(accountId);
    expect(pending, hasLength(1));
    expect(pending.single.remoteEntryId, 2);
  });
}
