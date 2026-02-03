import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../models/feed.dart';
import '../models/article.dart';
import 'core_providers.dart';

final unreadOnlyProvider = StateProvider<bool>((ref) => false);

/// Watches unread count for a given feedId. Use `null` for "All".
final unreadCountProvider = StreamProvider.family<int, int?>((
  ref,
  feedId,
) async* {
  final isar = ref.watch(isarProvider);

  final qb = isar.articles
      .filter()
      .optional(feedId != null, (q) => q.feedIdEqualTo(feedId!))
      .isReadEqualTo(false);

  // Emit immediately, then re-count on query change.
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
});

/// Watches all unread counts, returning a Map of feedId -> count.
/// Key null represents "All" unread count.
final allUnreadCountsProvider = StreamProvider<Map<int?, int>>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().isReadEqualTo(false);

  Future<Map<int?, int>> computeCounts() async {
    // Only fetch feedIds to save memory
    final feedIds = await qb.feedIdProperty().findAll();

    final counts = <int?, int>{};
    for (final id in feedIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    counts[null] = feedIds.length;
    return counts;
  }

  yield await computeCounts();
  await for (final _ in qb.watchLazy()) {
    yield await computeCounts();
  }
});

Stream<int> _watchUnreadCountByCategoryId(Isar isar, int categoryId) {
  final controller = StreamController<int>.broadcast();
  StreamSubscription<void>? feedSub;
  StreamSubscription<void>? articleSub;

  Future<List<int>> loadFeedIds() async {
    final qb = isar.feeds.filter();
    final filtered =
        categoryId < 0 ? qb.categoryIdIsNull() : qb.categoryIdEqualTo(categoryId);
    return filtered.idProperty().findAll();
  }

  Future<void> emitCount() async {
    final feedIds = await loadFeedIds();
    if (feedIds.isEmpty) {
      if (!controller.isClosed) controller.add(0);
      return;
    }
    final qb = isar.articles
        .filter()
        .anyOf(feedIds, (q, id) => q.feedIdEqualTo(id))
        .isReadEqualTo(false);
    if (!controller.isClosed) controller.add(await qb.count());
  }

  Future<void> watchArticles() async {
    await articleSub?.cancel();
    final feedIds = await loadFeedIds();
    if (feedIds.isEmpty) {
      if (!controller.isClosed) controller.add(0);
      return;
    }
    final qb = isar.articles
        .filter()
        .anyOf(feedIds, (q, id) => q.feedIdEqualTo(id))
        .isReadEqualTo(false);
    articleSub = qb.watchLazy().listen((_) {
      unawaited(emitCount());
    });
  }

  unawaited(emitCount());
  unawaited(watchArticles());

  final feedsQuery = categoryId < 0
      ? isar.feeds.filter().categoryIdIsNull()
      : isar.feeds.filter().categoryIdEqualTo(categoryId);
  feedSub = feedsQuery.watchLazy().listen((_) {
    unawaited(watchArticles());
    unawaited(emitCount());
  });

  controller.onCancel = () async {
    await feedSub?.cancel();
    await articleSub?.cancel();
    await controller.close();
  };
  return controller.stream;
}

final unreadCountByCategoryProvider = StreamProvider.family<int, int>((
  ref,
  categoryId,
) {
  final isar = ref.watch(isarProvider);
  return _watchUnreadCountByCategoryId(isar, categoryId);
});

final unreadCountUncategorizedProvider = StreamProvider<int>((ref) {
  final isar = ref.watch(isarProvider);
  return _watchUnreadCountByCategoryId(isar, -1);
});

/// Watches total count of Starred articles.
final starredCountProvider = StreamProvider<int>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().isStarredEqualTo(true);
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
});

/// Watches total count of Read Later articles.
final readLaterCountProvider = StreamProvider<int>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().isReadLaterEqualTo(true);
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
});
