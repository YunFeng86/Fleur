import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';

/// Service for detecting and repairing data inconsistencies.
///
/// Since we use denormalization (Article.categoryId duplicates Feed.categoryId),
/// we need defensive checks to ensure consistency is maintained.
class DataIntegrityService {
  DataIntegrityService(this._isar);

  final Isar _isar;

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
                : q.categoryIdEqualTo(feed.categoryId!);
          })
          .idProperty()
          .findAll();

      if (ids.isEmpty) continue;

      // Batch repair to avoid OOM
      const batchSize = 200;
      for (var i = 0; i < ids.length; i += batchSize) {
        await _isar.writeTxn(() async {
          final end = (i + batchSize > ids.length) ? ids.length : i + batchSize;
          final batch = ids.sublist(i, end);
          final articles = await _isar.articles.getAll(batch);

          final updates = <Article>[];
          for (final a in articles) {
            if (a == null) continue;
            a.categoryId = feed.categoryId;
            a.updatedAt = DateTime.now();
            updates.add(a);
          }

          if (updates.isNotEmpty) {
            await _isar.articles.putAll(updates);
          }
        });
      }

      fixedCount += ids.length;
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
                : q.categoryIdEqualTo(feed.categoryId!);
          })
          .count();

      mismatchedArticles += count;
    }

    // Check for orphaned articles (feedId doesn't exist)
    final allArticles = await _isar.articles.where().findAll();
    for (final article in allArticles) {
      if (!feedIds.contains(article.feedId)) {
        orphanedArticles++;
      }
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

    return await _isar.writeTxn(() async {
      int deleted = 0;

      // Find all orphaned article IDs
      final allArticles = await _isar.articles.where().findAll();
      final orphanedIds = <int>[];

      for (final article in allArticles) {
        if (!feedIds.contains(article.feedId)) {
          orphanedIds.add(article.id);
        }
      }

      if (orphanedIds.isEmpty) return 0;

      // Delete in batches
      const batchSize = 200;
      for (var i = 0; i < orphanedIds.length; i += batchSize) {
        final end = (i + batchSize > orphanedIds.length)
            ? orphanedIds.length
            : i + batchSize;
        final batch = orphanedIds.sublist(i, end);
        deleted += await _isar.articles.deleteAll(batch);
      }

      return deleted;
    });
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
