import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/rule.dart';
import '../models/tag.dart';

class ArticleRepository {
  ArticleRepository(this._isar);

  final Isar _isar;

  static const int defaultPageSize = 50;

  Stream<List<Article>> watchLatest({int? feedId, bool unreadOnly = false}) {
    var q = _isar.articles.where().sortByPublishedAtDesc();

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

  Future<List<Article>> fetchPage({
    required int offset,
    required int limit,
    int? feedId,
    int? categoryId,
    bool unreadOnly = false,
    bool starredOnly = false,
    bool readLaterOnly = false,
    int? tagId,
    String searchQuery = '',
    bool sortAscending = false,
    bool searchInContent = true,
  }) {
    final cid = categoryId;
    final tid = tagId;
    final q = searchQuery.trim();
    final hasQuery = q.isNotEmpty;
    final qb = _isar.articles
        .filter()
        .optional(feedId != null, (q) => q.feedIdEqualTo(feedId!))
        .optional(cid != null && cid < 0, (q) => q.categoryIdIsNull())
        .optional(cid != null && cid >= 0, (q) => q.categoryIdEqualTo(cid!))
        .optional(tid != null, (q) => q.tags((t) => t.idEqualTo(tid!)))
        .optional(unreadOnly, (q) => q.isReadEqualTo(false))
        .optional(starredOnly, (q) => q.isStarredEqualTo(true))
        .optional(readLaterOnly, (q) => q.isReadLaterEqualTo(true))
        .optional(
          hasQuery,
          (q0) => q0.group(
            (q1) => searchInContent
                ? q1
                      .titleContains(q, caseSensitive: false)
                      .or()
                      .authorContains(q, caseSensitive: false)
                      .or()
                      .linkContains(q, caseSensitive: false)
                      .or()
                      .contentHtmlContains(q, caseSensitive: false)
                      .or()
                      .fullContentHtmlContains(q, caseSensitive: false)
                : q1
                      .titleContains(q, caseSensitive: false)
                      .or()
                      .authorContains(q, caseSensitive: false)
                      .or()
                      .linkContains(q, caseSensitive: false),
          ),
        );

    final sorted = sortAscending
        ? qb.sortByPublishedAt()
        : qb.sortByPublishedAtDesc();
    return sorted.offset(offset).limit(limit).findAll();
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

  Future<void> toggleReadLater(int id) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.isReadLater = !a.isReadLater;
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

  Future<int> deleteReadUnstarredOlderThan(DateTime cutoffUtc) {
    return _isar.writeTxn(() async {
      return _isar.articles
          .filter()
          .isReadEqualTo(true)
          .isStarredEqualTo(false)
          .publishedAtLessThan(cutoffUtc)
          .deleteAll();
    });
  }

  Future<void> addTag(int articleId, Tag tag) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(articleId);
      if (a == null) return;
      a.tags.add(tag);
      a.updatedAt = DateTime.now();
      await a.tags.save();
      await _isar.articles.put(a); // Update updatedAt
    });
  }

  Future<void> removeTag(int articleId, Tag tag) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(articleId);
      if (a == null) return;
      a.tags.remove(tag);
      a.updatedAt = DateTime.now();
      await a.tags.save();
      await _isar.articles.put(a);
    });
  }

  Future<int> markAllRead({int? feedId, int? categoryId}) {
    return _isar.writeTxn(() async {
      final cid = categoryId;
      final qb = _isar.articles
          .filter()
          .optional(feedId != null, (q) => q.feedIdEqualTo(feedId!))
          .optional(cid != null && cid < 0, (q) => q.categoryIdIsNull())
          .optional(cid != null && cid >= 0, (q) => q.categoryIdEqualTo(cid!))
          .isReadEqualTo(false);

      final items = await qb.findAll();
      if (items.isEmpty) return 0;
      final now = DateTime.now();
      for (final a in items) {
        a.isRead = true;
        a.updatedAt = now;
      }
      await _isar.articles.putAll(items);
      return items.length;
    });
  }

  Future<List<Article>> getUnread({int? feedId}) {
    final q = _isar.articles.filter().isReadEqualTo(false);
    if (feedId != null) {
      return q.feedIdEqualTo(feedId).findAll();
    }
    return q.findAll();
  }

  Future<(List<Article> newArticles, List<Article> keywordArticles)> upsertMany(
    int feedId,
    List<Article> incoming, {
    List<Rule> rules = const [],
  }) {
    return _isar.writeTxn(() async {
      final enabledRules = rules
          .where((r) => r.enabled)
          .toList(growable: false);

      final newArticles = <Article>[];
      final keywordArticles = <Article>[];

      for (final a in incoming) {
        final existing = await _isar.articles
            .where()
            .linkFeedIdEqualTo(a.link, feedId)
            .findFirst();

        a.feedId = feedId;
        a.updatedAt = DateTime.now();
        a.fetchedAt = DateTime.now();

        bool isNew = false;

        if (existing != null) {
          a.id = existing.id;
          a.isRead = existing.isRead;
          a.isStarred = existing.isStarred;
          a.isReadLater = existing.isReadLater;
          a.fullContentHtml = existing.fullContentHtml;
          if (a.publishedAt.millisecondsSinceEpoch == 0) {
            a.publishedAt = existing.publishedAt;
          }
        } else {
          isNew = true;
          // Apply automation rules only on first insert so we don't override
          // user actions on subsequent refreshes.
          if (enabledRules.isNotEmpty) {
            final (markRead, star, notify) = _applyRules(enabledRules, a);
            if (markRead) a.isRead = true;
            if (star) a.isStarred = true;
            if (notify) keywordArticles.add(a);
          }
        }

        await _isar.articles.put(a);
        if (isNew) {
          newArticles.add(a);
        }
      }
      return (newArticles, keywordArticles);
    });
  }

  (bool markRead, bool star, bool notify) _applyRules(
    List<Rule> rules,
    Article a,
  ) {
    bool shouldMarkRead = false;
    bool shouldStar = false;
    bool shouldNotify = false;

    final keywordCache = <int, String>{};

    bool matches(Rule r) {
      final needle = keywordCache.putIfAbsent(
        r.id,
        () => r.keyword.trim().toLowerCase(),
      );
      if (needle.isEmpty) return false;

      bool contains(String? haystack) {
        if (haystack == null || haystack.isEmpty) return false;
        return haystack.toLowerCase().contains(needle);
      }

      if (r.matchTitle && contains(a.title)) return true;
      if (r.matchAuthor && contains(a.author)) return true;
      if (r.matchLink && contains(a.link)) return true;
      if (r.matchContent &&
          (contains(a.contentHtml) || contains(a.fullContentHtml))) {
        return true;
      }
      return false;
    }

    for (final r in rules) {
      if (!matches(r)) continue;
      if (r.autoMarkRead) shouldMarkRead = true;
      if (r.autoStar) shouldStar = true;
      if (r.notify) shouldNotify = true;
      if (shouldMarkRead && shouldStar && shouldNotify) break;
    }

    return (shouldMarkRead, shouldStar, shouldNotify);
  }
}
