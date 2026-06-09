import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../models/article.dart';
import 'core_providers.dart';
import 'query_providers.dart';

final unreadOnlyProvider = Provider<bool>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.unreadOnly),
  );
});

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
}, dependencies: [isarProvider]);

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
}, dependencies: [isarProvider]);

/// Watches total count of Starred articles.
final starredCountProvider = StreamProvider<int>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().isStarredEqualTo(true);
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
}, dependencies: [isarProvider]);

/// Watches total count of Read Later articles.
final readLaterCountProvider = StreamProvider<int>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().isReadLaterEqualTo(true);
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
}, dependencies: [isarProvider]);
