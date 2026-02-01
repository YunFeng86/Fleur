import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pool/pool.dart';

import '../../models/article.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/feed_repository.dart';
import '../../repositories/rule_repository.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_store.dart';
import '../rss/feed_parser.dart';
import '../rss/rss_client.dart';
import '../notifications/notification_service.dart';
import '../cache/article_cache_service.dart';
import '../../utils/keyword_filter.dart';

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
    required CategoryRepository categories,
    required ArticleRepository articles,
    required RuleRepository rules,
    required RssClient client,
    required FeedParser parser,
    required NotificationService notifications,
    required ArticleCacheService cache,
    required AppSettingsStore appSettingsStore,
  }) : _feeds = feeds,
       _categories = categories,
       _articles = articles,
       _rules = rules,
       _client = client,
       _parser = parser,
       _notifications = notifications,
       _cache = cache,
       _appSettingsStore = appSettingsStore;

  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final ArticleRepository _articles;
  final RuleRepository _rules;
  final RssClient _client;
  final FeedParser _parser;
  final NotificationService _notifications;
  final ArticleCacheService _cache;
  final AppSettingsStore _appSettingsStore;
  Future<void> _batchRefreshQueue = Future.value();

  Future<int> offlineCacheFeed(int feedId) async {
    final articles = await _articles.getUnread(feedId: feedId);
    return _cache.cacheArticles(articles);
  }

  Future<_EffectiveFeedSettings> _resolveSettings(
    Feed feed, {
    AppSettings? appSettings,
  }) async {
    final resolvedAppSettings = appSettings ?? await _appSettingsStore.load();
    final categoryId = feed.categoryId;
    final Category? category = categoryId == null
        ? null
        : await _categories.getById(categoryId);
    return _EffectiveFeedSettings.resolve(feed, category, resolvedAppSettings);
  }

  Future<_RefreshOutcome> _refreshFeedOnce(
    Feed feed,
    _EffectiveFeedSettings settings,
  ) async {
    final feedId = feed.id;

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

    final filteredItems = (!settings.filterEnabled ||
            settings.filterKeywords.trim().isEmpty)
        ? parsed.items
        : parsed.items
            .where(
              (it) => ReservedKeywordFilter.matches(
                pattern: settings.filterKeywords,
                fields: [it.title, it.author, it.link, it.contentHtml],
              ),
            )
            .toList(growable: false);

    final incoming = filteredItems
        .map((it) {
          final a = Article()
            ..remoteId = it.remoteId
            ..link = it.link
            ..title = it.title
            ..author = it.author
            ..contentHtml = it.contentHtml
            // Keep `publishedAt` at the model default (epoch) when missing so
            // upsert can preserve existing value; for brand-new items we will
            // fall back to fetchedAt during upsert.
            ..publishedAt = it.publishedAt?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return a;
        })
        .toList(growable: false);

    final rules = await _rules.getEnabled();
    final (newArticles, keywordArticles) = await _articles.upsertMany(
      feedId,
      incoming,
      rules: rules,
    );

    // Best-effort offline caching for newly discovered articles.
    if (settings.syncImages && newArticles.isNotEmpty) {
      // Don't let caching failures break the refresh flow.
      try {
        await _cache.cacheArticles(newArticles);
      } catch (_) {}
    }

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
    AppSettings? appSettings,
  }) async {
    final feed = await _feeds.getById(feedId);
    if (feed == null) {
      return FeedRefreshResult(
        feedId: feedId,
        incomingCount: 0,
        error: ArgumentError('Feed $feedId not found'),
      );
    }

    final settings = await _resolveSettings(feed, appSettings: appSettings);
    if (!settings.syncEnabled) {
      // Skip network refresh when sync is disabled for this feed (effective).
      return FeedRefreshResult(feedId: feedId, incomingCount: 0);
    }

    Object? lastError;
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    final sw = Stopwatch()..start();
    for (var i = 0; i < attempts; i++) {
      final checkedAt = DateTime.now();
      try {
        final out = await _refreshFeedOnce(feed, settings);
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

        // Exponential backoff: 500ms, 1000ms, 2000ms...
        // Gives network/DNS failures time to recover without wasting time on persistent errors
        if (i < attempts - 1) {
          final delayMs = 500 * (1 << i); // 2^i exponential growth
          await Future<void>.delayed(Duration(milliseconds: delayMs));
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

    // Load once per batch to avoid per-feed disk reads.
    final appSettings = await _appSettingsStore.load();

    final total = ids.length;
    var completed = 0;

    // Dynamic batch size based on total feeds:
    // - Small feeds (<=20): process all at once (no batching overhead)
    // - Medium feeds (21-100): batch by 20
    // - Large feeds (>100): batch by 50
    final batchSize = total <= 20 ? total : (total <= 100 ? 20 : 50);
    final results = <FeedRefreshResult>[];

    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize < total) ? i + batchSize : total;
      final batchIds = ids.sublist(i, end);

      // Limit concurrent HTTP connections to prevent resource exhaustion
      final pool = Pool(maxConcurrent < 1 ? 1 : maxConcurrent);
      final futures = <Future<void>>[];

      for (final id in batchIds) {
        futures.add(
          pool.withResource(() async {
            final r = await refreshFeedSafe(
              id,
              maxAttempts: maxAttemptsPerFeed,
              appSettings: appSettings,
            );
            results.add(r);
            completed++;
            onProgress?.call(completed, total);
          }),
        );
      }

      await Future.wait(futures);
      await pool.close();

      // Small pause between batches only for large feeds (>20)
      // Gives event loop time to process UI updates
      if (end < total && total > 20) {
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

class _EffectiveFeedSettings {
  const _EffectiveFeedSettings({
    required this.syncEnabled,
    required this.filterEnabled,
    required this.filterKeywords,
    required this.syncImages,
  });

  final bool syncEnabled;
  final bool filterEnabled;
  final String filterKeywords;
  final bool syncImages;

  static _EffectiveFeedSettings resolve(
    Feed feed,
    Category? category,
    AppSettings appSettings,
  ) {
    bool pickBool(bool? feedV, bool? catV, bool appV) {
      if (feedV != null) return feedV;
      if (catV != null) return catV;
      return appV;
    }

    String pickKeywords(String? feedV, String? catV, String appV) {
      final f = feedV?.trim();
      if (f != null && f.isNotEmpty) return f;
      final c = catV?.trim();
      if (c != null && c.isNotEmpty) return c;
      return appV;
    }

    return _EffectiveFeedSettings(
      syncEnabled: pickBool(
        feed.syncEnabled,
        category?.syncEnabled,
        appSettings.syncEnabled,
      ),
      filterEnabled: pickBool(
        feed.filterEnabled,
        category?.filterEnabled,
        appSettings.filterEnabled,
      ),
      filterKeywords: pickKeywords(
        feed.filterKeywords,
        category?.filterKeywords,
        appSettings.filterKeywords,
      ),
      syncImages: pickBool(
        feed.syncImages,
        category?.syncImages,
        appSettings.syncImages,
      ),
    );
  }
}
