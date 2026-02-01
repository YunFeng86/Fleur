import 'dart:async';

import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';
import '../models/rule.dart';
import '../models/tag.dart';
import '../services/html_sanitizer.dart';
import '../utils/content_hash.dart';
import '../utils/link_normalizer.dart';

class ArticleQuery {
  const ArticleQuery({
    this.feedId,
    this.categoryId,
    this.unreadOnly = false,
    this.starredOnly = false,
    this.readLaterOnly = false,
    this.tagId,
    this.searchQuery = '',
    this.sortAscending = false,
    this.searchInContent = true,
  });

  final int? feedId;
  final int? categoryId;
  final bool unreadOnly;
  final bool starredOnly;
  final bool readLaterOnly;
  final int? tagId;
  final String searchQuery;
  final bool sortAscending;
  final bool searchInContent;

  ArticleQuery copyWith({
    int? feedId,
    int? categoryId,
    bool? unreadOnly,
    bool? starredOnly,
    bool? readLaterOnly,
    int? tagId,
    String? searchQuery,
    bool? sortAscending,
    bool? searchInContent,
  }) {
    return ArticleQuery(
      feedId: feedId ?? this.feedId,
      categoryId: categoryId ?? this.categoryId,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      starredOnly: starredOnly ?? this.starredOnly,
      readLaterOnly: readLaterOnly ?? this.readLaterOnly,
      tagId: tagId ?? this.tagId,
      searchQuery: searchQuery ?? this.searchQuery,
      sortAscending: sortAscending ?? this.sortAscending,
      searchInContent: searchInContent ?? this.searchInContent,
    );
  }
}

class ArticleRepository {
  ArticleRepository(this._isar);

  final Isar _isar;

  static const int defaultPageSize = 50;

  Future<List<int>?> _resolveCategoryFeedIds(ArticleQuery query) async {
    if (query.feedId != null || query.categoryId == null) return null;
    final cid = query.categoryId!;
    final qb = _isar.feeds.filter();
    final filtered = cid < 0 ? qb.categoryIdIsNull() : qb.categoryIdEqualTo(cid);
    return filtered.idProperty().findAll();
  }

  QueryBuilder<Article, Article, QAfterFilterCondition> _buildQuery(
    ArticleQuery query, {
    List<int>? categoryFeedIds,
  }) {
    final tid = query.tagId;
    final q = query.searchQuery.trim();
    final hasQuery = q.isNotEmpty;
    return _isar.articles
        .filter()
        .optional(query.feedId != null, (q) => q.feedIdEqualTo(query.feedId!))
        .optional(
          query.feedId == null && categoryFeedIds != null,
          (q) => q.anyOf(
            categoryFeedIds!,
            (q, id) => q.feedIdEqualTo(id),
          ),
        )
        .optional(tid != null, (q) => q.tags((t) => t.idEqualTo(tid!)))
        .optional(query.unreadOnly, (q) => q.isReadEqualTo(false))
        .optional(query.starredOnly, (q) => q.isStarredEqualTo(true))
        .optional(query.readLaterOnly, (q) => q.isReadLaterEqualTo(true))
        .optional(
          hasQuery,
          (q0) => q0.group(
            (q1) => query.searchInContent
                ? q1
                      .titleContains(q, caseSensitive: false)
                      .or()
                      .authorContains(q, caseSensitive: false)
                      .or()
                      .linkContains(q, caseSensitive: false)
                      .or()
                      .contentHtmlContains(q, caseSensitive: false)
                      .or()
                      .extractedContentHtmlContains(q, caseSensitive: false)
                : q1
                      .titleContains(q, caseSensitive: false)
                      .or()
                      .authorContains(q, caseSensitive: false)
                      .or()
                      .linkContains(q, caseSensitive: false),
          ),
        );
  }

  QueryBuilder<Article, Article, QAfterSortBy> _applySort(
    QueryBuilder<Article, Article, QAfterFilterCondition> qb, {
    required bool sortAscending,
  }) {
    return sortAscending ? qb.sortByPublishedAt() : qb.sortByPublishedAtDesc();
  }

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

  Future<List<Article>> fetchPage(
    ArticleQuery query, {
    required int offset,
    required int limit,
  }) async {
    final feedIds = await _resolveCategoryFeedIds(query);
    if (feedIds != null && feedIds.isEmpty) return [];
    final qb = _buildQuery(query, categoryFeedIds: feedIds);
    final sorted = _applySort(qb, sortAscending: query.sortAscending);
    return sorted.offset(offset).limit(limit).findAll();
  }

  Stream<void> watchQueryChanges(ArticleQuery query) {
    // Since setCategory now updates Feed and Articles atomically in a single
    // transaction, we no longer need to watch the Feed table separately.
    // Article table changes alone are sufficient to detect all updates.
    final controller = StreamController<void>.broadcast();
    StreamSubscription<void>? articleSub;

    Future<void> watchArticles() async {
      await articleSub?.cancel();
      final feedIds = await _resolveCategoryFeedIds(query);
      if (feedIds != null && feedIds.isEmpty) {
        if (!controller.isClosed) controller.add(null);
        return;
      }
      final qb = _buildQuery(query, categoryFeedIds: feedIds);
      final sorted = _applySort(qb, sortAscending: query.sortAscending);
      articleSub = sorted.watchLazy().listen((_) {
        if (!controller.isClosed) controller.add(null);
      });
    }

    unawaited(watchArticles());

    controller.onCancel = () async {
      await articleSub?.cancel();
      await controller.close();
    };
    return controller.stream;
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

  Future<void> setExtractedContent(int id, String html) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      // [V2.0] Sanitize HTML to prevent XSS attacks
      a.extractedContentHtml = HtmlSanitizer.sanitize(html);
      a.contentSource = ContentSource.extracted;
      a.updatedAt = DateTime.now();
      await _isar.articles.put(a);
    });
  }

  Future<void> markExtractionFailed(int id) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.contentSource = ContentSource.extractionFailed;
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
    return _markAllReadBatched(feedId: feedId, categoryId: categoryId);
  }

  Future<int> _markAllReadBatched({int? feedId, int? categoryId}) async {
    final query = ArticleQuery(
      feedId: feedId,
      categoryId: categoryId,
      unreadOnly: true,
    );
    final feedIds = await _resolveCategoryFeedIds(query);
    if (feedIds != null && feedIds.isEmpty) return 0;
    final qb = _isar.articles
        .filter()
        .optional(feedId != null, (q) => q.feedIdEqualTo(feedId!))
        .optional(
          feedId == null && feedIds != null,
          (q) => q.anyOf(feedIds!, (q, id) => q.feedIdEqualTo(id)),
        )
        .isReadEqualTo(false);

    // 先取出 ID，避免单次事务加载过多数据。
    final ids = await qb.idProperty().findAll();
    if (ids.isEmpty) return 0;

    // Batch size optimized for Isar write performance (balance between memory usage and transaction overhead)
    const batchSize = 200;
    for (var i = 0; i < ids.length; i += batchSize) {
      final end = i + batchSize > ids.length ? ids.length : i + batchSize;
      final batchIds = ids.sublist(i, end);
      await _isar.writeTxn(() async {
        final items = await _isar.articles.getAll(batchIds);
        final now = DateTime.now();
        final updates = <Article>[];
        for (final a in items) {
          if (a == null) continue;
          a.isRead = true;
          a.updatedAt = now;
          updates.add(a);
        }
        if (updates.isNotEmpty) {
          await _isar.articles.putAll(updates);
        }
      });
    }
    return ids.length;
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
      if (incoming.isEmpty) return (<Article>[], <Article>[]);

      final enabledRules = rules
          .where((r) => r.enabled)
          .toList(growable: false);

      final newArticles = <Article>[];
      final keywordArticles = <Article>[];

      // Get Feed's categoryId once before the loop (prevents N+1 query problem)
      // Within a transaction, feedId and categoryId won't change
      final feed = await _isar.feeds.get(feedId);
      if (feed == null) {
        throw ArgumentError('Feed $feedId not found');
      }
      final categoryId = feed.categoryId;

      // [FIX] Batch query all existing articles by remoteId and links (eliminates N+1 query)
      // Normalize links first to ensure consistent matching
      final normalizedLinks = <String>[];
      final remoteIds = <String>[];
      for (final a in incoming) {
        a.link = LinkNormalizer.normalize(a.link);
        normalizedLinks.add(a.link);
        if (a.remoteId != null && a.remoteId!.trim().isNotEmpty) {
          remoteIds.add(a.remoteId!);
        }
      }

      // Query by both remoteId (primary) and link (fallback)
      // This prevents duplicates even if URL changes but guid stays the same
      final existingArticles = await _isar.articles
          .filter()
          .feedIdEqualTo(feedId)
          .group((q) => q
              .anyOf(normalizedLinks, (q, link) => q.linkEqualTo(link))
              .or()
              .optional(
                remoteIds.isNotEmpty,
                (q) => q.anyOf(remoteIds, (q, rid) => q.remoteIdEqualTo(rid)),
              ))
          .findAll();

      // Build dual lookup maps for O(1) access
      // remoteId takes priority over link for deduplication
      final existingByRemoteId = <String, Article>{};
      final existingByLink = <String, Article>{};
      for (var article in existingArticles) {
        if (article.remoteId != null && article.remoteId!.isNotEmpty) {
          existingByRemoteId[article.remoteId!] = article;
        }
        existingByLink[article.link] = article;
      }

      final now = DateTime.now();

      for (final a in incoming) {
        // Link already normalized above

        // [V2.0] Compute content hash for change detection
        final newHash = ContentHash.compute(a.contentHtml);

        // Dual-key O(1) lookup: remoteId takes priority over link
        // This prevents duplicates when URLs change but guid remains the same
        final existing = (a.remoteId != null && a.remoteId!.isNotEmpty)
            ? existingByRemoteId[a.remoteId!] ?? existingByLink[a.link]
            : existingByLink[a.link];

        a.feedId = feedId;
        a.categoryId = categoryId; // [V2.0] Denormalize categoryId
        a.updatedAt = now;
        a.fetchedAt = now;

        bool isNew = false;

        if (existing != null) {
          a.id = existing.id;

          // [V2.0] Only update if content changed
          if (existing.contentHash != newHash) {
            a.contentHash = newHash;
            a.isRead = false; // Content changed -> mark unread
          } else {
            // Content unchanged -> preserve user state
            a.isRead = existing.isRead;
            a.contentHash = existing.contentHash;
          }

          a.isStarred = existing.isStarred;
          a.isReadLater = existing.isReadLater;
          a.contentSource = existing.contentSource;
          a.extractedContentHtml = existing.extractedContentHtml;
          if (a.contentHtml == null || a.contentHtml!.trim().isEmpty) {
            a.contentHtml = existing.contentHtml;
          }
          if (a.publishedAt.millisecondsSinceEpoch == 0) {
            a.publishedAt = existing.publishedAt;
          }
        } else {
          isNew = true;
          a.contentHash = newHash;

          // Apply automation rules only on first insert so we don't override
          // user actions on subsequent refreshes.
          if (enabledRules.isNotEmpty) {
            final (markRead, star, notify) = _applyRules(enabledRules, a);
            if (markRead) a.isRead = true;
            if (star) a.isStarred = true;
            if (notify) keywordArticles.add(a);
          }
        }

        if (isNew) {
          newArticles.add(a);
        }
      }

      // Batch write all articles at once (more efficient than individual puts)
      await _isar.articles.putAll(incoming);

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
            (contains(a.contentHtml) || contains(a.extractedContentHtml))) {
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
