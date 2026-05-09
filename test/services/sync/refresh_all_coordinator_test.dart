import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/feed.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/refresh_all_coordinator.dart';
import 'package:fleur/services/sync/sync_service.dart';

import '../../test_utils/critical_workflow_test_support.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  _FakeFeedRepository(this.feeds);

  final List<Feed> feeds;

  @override
  Future<List<Feed>> getAll() async => feeds;
}

Feed _feed(int id) {
  return Feed()
    ..id = id
    ..url = 'https://example.com/$id.xml'
    ..title = 'Feed $id';
}

void main() {
  test('miniflux account sync does not refresh upstream sources', () async {
    final syncService = FakeSyncService();
    final coordinator = AccountSyncCoordinator(
      account: buildTestAccount(type: AccountType.miniflux),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
    );

    final result = await coordinator.syncAccount(
      trigger: AccountSyncTrigger.foregroundAuto,
    );

    expect(result.ok, isTrue);
    expect(syncService.refreshCalls, [
      [1],
    ]);
  });

  test(
    'miniflux source refresh triggers upstream refresh before syncing',
    () async {
      final events = <String>[];
      final syncService = FakeSyncService(
        onRefresh: (feedIds) async {
          events.add('sync');
          return const BatchRefreshResult(<FeedRefreshResult>[]);
        },
      );
      final coordinator = RefreshSourcesCoordinator(
        account: buildTestAccount(type: AccountType.miniflux),
        feeds: _FakeFeedRepository([_feed(1)]),
        syncService: syncService,
        refreshAllRemoteFeeds: () async {
          events.add('upstream');
        },
      );

      final result = await coordinator.refreshSources(
        trigger: RefreshSourcesTrigger.foregroundAuto,
      );

      expect(result.ok, isTrue);
      expect(events, ['upstream', 'sync']);
      expect(syncService.refreshCalls, [
        [1],
      ]);
    },
  );

  test('miniflux source refresh failure skips local sync', () async {
    final error = StateError('remote refresh failed');
    final syncService = FakeSyncService();
    final coordinator = RefreshSourcesCoordinator(
      account: buildTestAccount(type: AccountType.miniflux),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
      refreshAllRemoteFeeds: () async {
        throw error;
      },
    );

    final result = await coordinator.refreshSources(
      trigger: RefreshSourcesTrigger.background,
    );

    expect(result.ok, isFalse);
    expect(result.error, same(error));
    expect(result.batch.firstError?.error, same(error));
    expect(syncService.refreshCalls, isEmpty);
  });

  test('local source refresh syncs local feed sources', () async {
    final syncService = FakeSyncService();
    final coordinator = RefreshSourcesCoordinator(
      account: buildTestAccount(type: AccountType.local),
      feeds: _FakeFeedRepository([_feed(1), _feed(2)]),
      syncService: syncService,
    );

    final result = await coordinator.refreshSources(
      trigger: RefreshSourcesTrigger.manual,
    );

    expect(result.ok, isTrue);
    expect(syncService.refreshCalls, [
      [1, 2],
    ]);
  });

  test('fever account sync syncs remote state', () async {
    final syncService = FakeSyncService();
    final coordinator = AccountSyncCoordinator(
      account: buildTestAccount(type: AccountType.fever),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
    );

    final result = await coordinator.syncAccount(
      trigger: AccountSyncTrigger.manual,
    );

    expect(result.ok, isTrue);
    expect(syncService.refreshCalls, [
      [1],
    ]);
  });

  test('fever source refresh reports unsupported without syncing', () async {
    final syncService = FakeSyncService();
    final coordinator = RefreshSourcesCoordinator(
      account: buildTestAccount(type: AccountType.fever),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
    );

    final result = await coordinator.refreshSources(
      trigger: RefreshSourcesTrigger.manual,
    );

    expect(result.ok, isFalse);
    expect(result.error, isA<RefreshSourcesUnsupportedException>());
    expect(syncService.refreshCalls, isEmpty);
  });
}
