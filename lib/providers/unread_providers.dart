import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

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

final unreadCountByCategoryProvider = StreamProvider.family<int, int>((
  ref,
  categoryId,
) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles
      .filter()
      .categoryIdEqualTo(categoryId)
      .isReadEqualTo(false);
  yield await qb.count();
  await for (final _ in qb.watchLazy()) {
    yield await qb.count();
  }
});

final unreadCountUncategorizedProvider = StreamProvider<int>((ref) async* {
  final isar = ref.watch(isarProvider);
  final qb = isar.articles.filter().categoryIdIsNull().isReadEqualTo(false);
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
