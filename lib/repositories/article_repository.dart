import 'dart:async';

import 'package:isar_community/isar.dart';

import 'article_merge_policy.dart';
import '../models/article.dart';
import '../models/feed.dart';
import '../models/tag.dart';
import '../services/html_sanitizer.dart';

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
  final ArticleMergePolicy _mergePolicy = const ArticleMergePolicy();

  static const int defaultPageSize = 50;

  QueryBuilder<Article, Article, QAfterFilterCondition> _buildQuery(
    ArticleQuery query,
  ) {
    final tid = query.tagId;
    final q = query.searchQuery.trim();
    final hasQuery = q.isNotEmpty;
    return _isar.articles
        .filter()
        .optional(query.feedId != null, (q) => q.feedIdEqualTo(query.feedId!))
        .optional(
          query.feedId == null && query.categoryId != null,
          (q) => q.categoryIdEqualTo(query.categoryId),
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
    final qb = _buildQuery(query);
    final sorted = _applySort(qb, sortAscending: query.sortAscending);
    return sorted.offset(offset).limit(limit).findAll();
  }

  Future<List<int>> fetchPageIds(
    ArticleQuery query, {
    required int offset,
    required int limit,
  }) async {
    final qb = _buildQuery(query);
    final sorted = _applySort(qb, sortAscending: query.sortAscending);
    return sorted.offset(offset).limit(limit).idProperty().findAll();
  }

  Stream<void> watchQueryChanges(ArticleQuery query) {
    // Since setCategory now updates Feed and Articles atomically in a single
    // transaction, we no longer need to watch the Feed table separately.
    // Article table changes alone are sufficient to detect all updates.
    final controller = StreamController<void>.broadcast();
    StreamSubscription<void>? articleSub;

    Future<void> watchArticles() async {
      await articleSub?.cancel();
      final qb = _buildQuery(query);
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

  Future<void> setPreferredContentView(int id, ArticleContentView view) {
    return _isar.writeTxn(() async {
      final a = await _isar.articles.get(id);
      if (a == null) return;
      a.preferredContentView = view;
      // Client-only article preference: keep updatedAt untouched so remote-backed
      // sync does not treat this as a remote article-content mutation.
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
    final qb = _isar.articles
        .filter()
        .optional(feedId != null, (q) => q.feedIdEqualTo(feedId!))
        .optional(
          feedId == null && categoryId != null,
          (q) => q.categoryIdEqualTo(categoryId),
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

  Future<List<Article>> upsertMany(
    int feedId,
    List<Article> incoming, {
    bool preserveUserState = true,
  }) {
    if (incoming.isEmpty) return Future.value(<Article>[]);
    final ingestionPlan = _mergePolicy.prepareIncoming(
      incoming,
      preserveUserState: preserveUserState,
    );
    return _isar.writeTxn(() async {
      final newArticles = <Article>[];

      final feed = await _isar.feeds.get(feedId);
      if (feed == null) {
        throw ArgumentError('Feed $feedId not found');
      }
      final categoryId = feed.categoryId;

      final existingArticles = await _isar.articles
          .filter()
          .feedIdEqualTo(feedId)
          .group(
            (q) => q
                .anyOf(
                  ingestionPlan.linkLookupKeys,
                  (q, link) => q.linkEqualTo(link),
                )
                .or()
                .optional(
                  ingestionPlan.remoteIds.isNotEmpty,
                  (q) => q.anyOf(
                    ingestionPlan.remoteIds,
                    (q, rid) => q.remoteIdEqualTo(rid),
                  ),
                ),
          )
          .findAll();

      final lookup = ArticleMergeLookup(existingArticles);
      final now = DateTime.now();

      for (final a in incoming) {
        final isNew = _mergePolicy.merge(
          incoming: a,
          existing: lookup.findFor(a),
          feedId: feedId,
          categoryId: categoryId,
          now: now,
          preserveUserState: preserveUserState,
        );
        if (isNew) {
          newArticles.add(a);
        }
      }

      await _isar.articles.putAll(incoming);

      return newArticles;
    });
  }
}
