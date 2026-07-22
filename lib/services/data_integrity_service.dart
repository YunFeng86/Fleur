import 'package:isar_community/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';

/// Service for detecting and repairing data inconsistencies.
///
/// Since we use denormalization (Article.categoryId duplicates Feed.categoryId),
/// we need defensive checks to ensure consistency is maintained.
class DataIntegrityService {
  DataIntegrityService(this._isar);

  final Isar _isar;

  static const int _scanBatchSize = 500;

  /// Repairs Article.categoryId that doesn't match Feed.categoryId.
  ///
  /// Returns the number of articles fixed.
  ///
  /// This should be called:
  /// - On app startup (to fix any corruption from crashes/bugs)
  /// - After database migrations
  /// - Periodically in background (optional)
  Future<int> repairCategoryIdMismatch() async {
    int fixedCount = 0;

    final feeds = await _isar.feeds.where().findAll();
    for (final feed in feeds) {
      // Find articles where categoryId doesn't match the feed's categoryId
      final ids = await _isar.articles
          .filter()
          .feedIdEqualTo(feed.id)
          .not()
          .group((q) {
            return feed.categoryId == null
                ? q.categoryIdIsNull()
                : q.categoryIdEqualTo(feed.categoryId);
          })
          .idProperty()
          .findAll();

      if (ids.isEmpty) continue;

      // Batch repair to avoid OOM
      const batchSize = 200;
      var feedFixedCount = 0;
      for (var i = 0; i < ids.length; i += batchSize) {
        await _isar.writeTxn(() async {
          final end = (i + batchSize > ids.length) ? ids.length : i + batchSize;
          final batch = ids.sublist(i, end);
          final currentFeed = await _isar.feeds.get(feed.id);
          if (currentFeed == null) return;
          final articles = await _isar.articles.getAll(batch);

          final updates = <Article>[];
          for (final a in articles) {
            if (a == null) continue;
            if (a.categoryId == currentFeed.categoryId) continue;
            a.categoryId = currentFeed.categoryId;
            a.updatedAt = DateTime.now();
            updates.add(a);
          }

          if (updates.isNotEmpty) {
            await _isar.articles.putAll(updates);
            feedFixedCount += updates.length;
          }
        });
      }

      fixedCount += feedFixedCount;
    }

    return fixedCount;
  }

  /// Returns a summary of potential data inconsistencies without fixing them.
  ///
  /// Useful for diagnostics and debugging.
  Future<IntegrityReport> check() async {
    int mismatchedArticles = 0;
    int orphanedArticles = 0;

    final feeds = await _isar.feeds.where().findAll();
    final feedIds = feeds.map((f) => f.id).toSet();

    for (final feed in feeds) {
      final count = await _isar.articles
          .filter()
          .feedIdEqualTo(feed.id)
          .not()
          .group((q) {
            return feed.categoryId == null
                ? q.categoryIdIsNull()
                : q.categoryIdEqualTo(feed.categoryId);
          })
          .count();

      mismatchedArticles += count;
    }

    // Check for orphaned articles (feedId doesn't exist)
    var lastId = -1;
    while (true) {
      final q = _isar.articles
          .where()
          .idGreaterThan(lastId)
          .limit(_scanBatchSize);
      final ids = await q.idProperty().findAll();
      if (ids.isEmpty) break;
      final batchFeedIds = await q.feedIdProperty().findAll();
      for (var i = 0; i < ids.length; i++) {
        if (!feedIds.contains(batchFeedIds[i])) {
          orphanedArticles++;
        }
      }
      lastId = ids.last;
    }

    return IntegrityReport(
      mismatchedCategoryIds: mismatchedArticles,
      orphanedArticles: orphanedArticles,
    );
  }

  /// Removes articles whose feed no longer exists.
  ///
  /// Returns the number of articles deleted.
  Future<int> cleanOrphanedArticles() async {
    final feeds = await _isar.feeds.where().findAll();
    final feedIds = feeds.map((f) => f.id).toSet();

    var deleted = 0;
    var lastId = -1;

    while (true) {
      final q = _isar.articles
          .where()
          .idGreaterThan(lastId)
          .limit(_scanBatchSize);
      final ids = await q.idProperty().findAll();
      if (ids.isEmpty) break;
      final batchFeedIds = await q.feedIdProperty().findAll();

      final orphanedIds = <int>[];
      for (var i = 0; i < ids.length; i++) {
        if (!feedIds.contains(batchFeedIds[i])) {
          orphanedIds.add(ids[i]);
        }
      }

      if (orphanedIds.isNotEmpty) {
        deleted += await _isar.writeTxn(() async {
          return _isar.articles.deleteAll(orphanedIds);
        });
      }

      lastId = ids.last;
    }

    return deleted;
  }
}

class IntegrityReport {
  const IntegrityReport({
    required this.mismatchedCategoryIds,
    required this.orphanedArticles,
  });

  final int mismatchedCategoryIds;
  final int orphanedArticles;

  bool get hasIssues => mismatchedCategoryIds > 0 || orphanedArticles > 0;

  @override
  String toString() {
    return 'IntegrityReport('
        'mismatchedCategoryIds: $mismatchedCategoryIds, '
        'orphanedArticles: $orphanedArticles'
        ')';
  }
}
