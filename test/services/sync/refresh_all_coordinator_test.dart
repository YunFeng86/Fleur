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
  test('local refresh only syncs local feeds', () async {
    var upstreamCalls = 0;
    final syncService = FakeSyncService();
    final coordinator = RefreshAllCoordinator(
      account: buildTestAccount(type: AccountType.local),
      feeds: _FakeFeedRepository([_feed(1), _feed(2)]),
      syncService: syncService,
      refreshAllRemoteFeeds: () async {
        upstreamCalls++;
      },
    );

    final result = await coordinator.refreshAll(
      trigger: RefreshAllTrigger.manual,
    );

    expect(result.ok, isTrue);
    expect(upstreamCalls, 0);
    expect(syncService.refreshCalls, [
      [1, 2],
    ]);
  });

  test('miniflux refresh triggers upstream refresh before syncing', () async {
    final events = <String>[];
    final syncService = FakeSyncService(
      onRefresh: (feedIds) async {
        events.add('sync');
        return const BatchRefreshResult(<FeedRefreshResult>[]);
      },
    );
    final coordinator = RefreshAllCoordinator(
      account: buildTestAccount(type: AccountType.miniflux),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
      refreshAllRemoteFeeds: () async {
        events.add('upstream');
      },
    );

    final result = await coordinator.refreshAll(
      trigger: RefreshAllTrigger.foregroundAuto,
    );

    expect(result.ok, isTrue);
    expect(events, ['upstream', 'sync']);
    expect(syncService.refreshCalls, [
      [1],
    ]);
  });

  test('miniflux upstream failure skips local sync', () async {
    final error = StateError('remote refresh failed');
    final syncService = FakeSyncService();
    final coordinator = RefreshAllCoordinator(
      account: buildTestAccount(type: AccountType.miniflux),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
      refreshAllRemoteFeeds: () async {
        throw error;
      },
    );

    final result = await coordinator.refreshAll(
      trigger: RefreshAllTrigger.background,
    );

    expect(result.ok, isFalse);
    expect(result.error, same(error));
    expect(result.batch.firstError?.error, same(error));
    expect(syncService.refreshCalls, isEmpty);
  });

  test('fever refresh syncs remote state without upstream refresh', () async {
    var upstreamCalls = 0;
    final syncService = FakeSyncService();
    final coordinator = RefreshAllCoordinator(
      account: buildTestAccount(type: AccountType.fever),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
      refreshAllRemoteFeeds: () async {
        upstreamCalls++;
      },
    );

    final result = await coordinator.refreshAll(
      trigger: RefreshAllTrigger.manual,
    );

    expect(result.ok, isTrue);
    expect(upstreamCalls, 0);
    expect(syncService.refreshCalls, [
      [1],
    ]);
  });
}
