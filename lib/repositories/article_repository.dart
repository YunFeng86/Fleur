import 'package:isar/isar.dart';

import '../models/article.dart';

class ArticleRepository {
  ArticleRepository(this._isar);

  final Isar _isar;

  Stream<List<Article>> watchLatest({int? feedId, bool unreadOnly = false}) {
    var q = _isar.articles
        .where()
        .sortByPublishedAtDesc();

    // Isar's `where()` doesn't support filtering by arbitrary fields; use filter().
    // We keep a separate branch to preserve sorting.
    if (feedId == null && !unreadOnly) {
      return q.watch(fireImmediately: true);
    }

    final f = _isar.articles.filter();
    final filtered = (feedId == null ? f : f.feedIdEqualTo(feedId))
        .optional(unreadOnly, (q) => q.isReadEqualTo(false))
        .sortByPublishedAtDesc();
    return filtered.watch(fireImmediately: true);
  }

  Stream<Article?> watchById(int id) {
    return _isar.articles.watchObject(id, fireImmediately: true);
  }

  Future<Article?> getById(int id) {
    return _isar.articles.get(id);
  }

  Future<void> markRead(int id, bool isRead) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.isRead = isRead;
      a.updatedAt = DateTime.now();
      await _isar.articles.put(a);
    });
  }

  Future<void> toggleStar(int id) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.isStarred = !a.isStarred;
      a.updatedAt = DateTime.now();
      await _isar.articles.put(a);
    });
  }

  Future<void> setFullContent(int id, String html) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.fullContentHtml = html;
      a.updatedAt = DateTime.now();
      await _isar.articles.put(a);
    });
  }

  Future<void> upsertMany(int feedId, List<Article> incoming) {
    return _isar.writeTxn(() async {
      for (final a in incoming) {
        final existing = await _isar.articles
            .where()
            .linkFeedIdEqualTo(a.link, feedId)
            .findFirst();

        a.feedId = feedId;
        a.updatedAt = DateTime.now();
        a.fetchedAt = DateTime.now();

        if (existing != null) {
          a.id = existing.id;
          a.isRead = existing.isRead;
          a.isStarred = existing.isStarred;
          a.fullContentHtml = existing.fullContentHtml;
          if (a.publishedAt.millisecondsSinceEpoch == 0) {
            a.publishedAt = existing.publishedAt;
          }
        }

        await _isar.articles.put(a);
      }
    });
  }
}
