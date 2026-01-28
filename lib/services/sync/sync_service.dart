import 'dart:async';

import 'package:dio/dio.dart';

import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/feed_repository.dart';
import '../../repositories/rule_repository.dart';
import '../rss/feed_parser.dart';
import '../rss/rss_client.dart';
import '../notifications/notification_service.dart';
import '../cache/article_cache_service.dart';

class FeedRefreshResult {
  const FeedRefreshResult({
    required this.feedId,
    required this.incomingCount,
    this.error,
  });

  final int feedId;
  final int incomingCount;
  final Object? error;

  bool get ok => error == null;
}

class BatchRefreshResult {
  const BatchRefreshResult(this.results);

  final List<FeedRefreshResult> results;

  int get okCount => results.where((r) => r.ok).length;
  int get errorCount => results.length - okCount;
  int get incomingTotal => results.fold(0, (sum, r) => sum + r.incomingCount);
  FeedRefreshResult? get firstError => results
      .cast<FeedRefreshResult?>()
      .firstWhere((r) => r?.error != null, orElse: () => null);
}

class SyncService {
  SyncService({
    required FeedRepository feeds,
    required ArticleRepository articles,
    required RuleRepository rules,
    required RssClient client,
    required FeedParser parser,
    required NotificationService notifications,
    required ArticleCacheService cache,
  }) : _feeds = feeds,
       _articles = articles,
       _rules = rules,
       _client = client,
       _parser = parser,
       _notifications = notifications,
       _cache = cache;

  final FeedRepository _feeds;
  final ArticleRepository _articles;
  final RuleRepository _rules;
  final RssClient _client;
  final FeedParser _parser;
  final NotificationService _notifications;
  final ArticleCacheService _cache;
  Future<void> _batchRefreshQueue = Future.value();

  Future<int> offlineCacheFeed(int feedId) async {
    final articles = await _articles.getUnread(feedId: feedId);
    return _cache.cacheArticles(articles);
  }

  Future<_RefreshOutcome> _refreshFeedOnce(int feedId) async {
    final feed = await _feeds.getById(feedId);
    if (feed == null) {
      return const _RefreshOutcome(feedId: -1, statusCode: 0, incomingCount: 0);
    }

    final fetched = await _client.fetchXml(
      feed.url,
      ifNoneMatch: feed.etag,
      ifModifiedSince: feed.lastModified,
    );

    final status = fetched.statusCode;
    if (status == 304) {
      return _RefreshOutcome(
        feedId: feedId,
        statusCode: 304,
        incomingCount: 0,
        etag: fetched.etag,
        lastModified: fetched.lastModified,
      );
    }
    if (status != 200) {
      throw Exception('Feed fetch failed: HTTP $status');
    }

    final parsed = _parser.parse(fetched.body);

    await _feeds.updateMeta(
      id: feedId,
      title: parsed.title,
      siteUrl: parsed.siteUrl,
      description: parsed.description,
      lastSyncedAt: DateTime.now(),
    );

    final incoming = parsed.items
        .map((it) {
          final a = Article()
            ..remoteId = it.remoteId
            ..link = it.link
            ..title = it.title
            ..author = it.author
            ..contentHtml = it.contentHtml
            ..categoryId = feed.categoryId
            ..publishedAt = (it.publishedAt ?? DateTime.now()).toUtc();
          return a;
        })
        .toList(growable: false);

    final rules = await _rules.getEnabled();
    final (newArticles, keywordArticles) = await _articles.upsertMany(
      feedId,
      incoming,
      rules: rules,
    );

    if (keywordArticles.isNotEmpty) {
      await _notifications.showKeywordArticlesNotification(keywordArticles);
    } else if (newArticles.isNotEmpty) {
      await _notifications.showNewArticlesNotification(newArticles);
    }

    return _RefreshOutcome(
      feedId: feedId,
      statusCode: 200,
      incomingCount: incoming.length,
      etag: fetched.etag,
      lastModified: fetched.lastModified,
    );
  }

  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
  }) async {
    Object? lastError;
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    final sw = Stopwatch()..start();
    for (var i = 0; i < attempts; i++) {
      final checkedAt = DateTime.now();
      try {
        final out = await _refreshFeedOnce(feedId);
        sw.stop();

        await _feeds.updateSyncState(
          id: feedId,
          lastCheckedAt: checkedAt,
          lastStatusCode: out.statusCode,
          lastDurationMs: sw.elapsedMilliseconds,
          lastIncomingCount: out.incomingCount,
          etag: out.etag,
          lastModified: out.lastModified,
          clearError: true,
        );

        return FeedRefreshResult(
          feedId: feedId,
          incomingCount: out.incomingCount,
        );
      } catch (e) {
        lastError = e;
        // Keep duration per attempt; store the last attempt duration.
        sw.stop();
        final statusCode = e is DioException ? e.response?.statusCode : null;
        await _feeds.updateSyncState(
          id: feedId,
          lastCheckedAt: checkedAt,
          lastStatusCode: statusCode,
          lastDurationMs: sw.elapsedMilliseconds,
          lastIncomingCount: 0,
          lastError: e.toString(),
          lastErrorAt: DateTime.now(),
          clearError: false,
        );

        // Small backoff so quick transient failures (DNS/timeout) have a chance
        // to recover without blocking the whole batch for too long.
        if (i < attempts - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          sw
            ..reset()
            ..start();
        }
      }
    }
    return FeedRefreshResult(
      feedId: feedId,
      incomingCount: 0,
      error: lastError ?? Exception('Unknown sync error'),
    );
  }

  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
  }) {
    final task = _batchRefreshQueue.then((_) {
      return _refreshFeedsSafeImpl(
        feedIds,
        maxConcurrent: maxConcurrent,
        maxAttemptsPerFeed: maxAttemptsPerFeed,
        onProgress: onProgress,
      );
    });
    _batchRefreshQueue = task.then((_) {}).catchError((_) {});
    return task;
  }

  Future<BatchRefreshResult> _refreshFeedsSafeImpl(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
  }) async {
    final ids = feedIds.toList(growable: false);
    if (ids.isEmpty) return const BatchRefreshResult([]);

    final total = ids.length;
    var completed = 0;

    // Split into batches to avoid creating too many futures at once
    const batchSize = 10;
    final results = <FeedRefreshResult>[];

    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize < total) ? i + batchSize : total;
      final batchIds = ids.sublist(i, end);

      final sem = _Semaphore(maxConcurrent < 1 ? 1 : maxConcurrent);
      final futures = <Future<void>>[];

      for (final id in batchIds) {
        futures.add(() async {
          await sem.acquire();
          try {
            final r = await refreshFeedSafe(
              id,
              maxAttempts: maxAttemptsPerFeed,
            );
            results.add(r);
            completed++;
            onProgress?.call(completed, total);
          } finally {
            sem.release();
          }
        }());
      }

      await Future.wait(futures);

      // Small pause between batches to let the event loop process other events
      if (end < total) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    return BatchRefreshResult(results);
  }
}

class _RefreshOutcome {
  const _RefreshOutcome({
    required this.feedId,
    required this.statusCode,
    required this.incomingCount,
    this.etag,
    this.lastModified,
  });

  final int feedId;
  final int statusCode;
  final int incomingCount;
  final String? etag;
  final String? lastModified;
}

class _Semaphore {
  _Semaphore(this._max);
  final int _max;
  int _cur = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_cur < _max) {
      _cur++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_cur > 0) _cur--;
    if (_waiters.isNotEmpty && _cur < _max) {
      _cur++;
      _waiters.removeAt(0).complete();
    }
  }
}
