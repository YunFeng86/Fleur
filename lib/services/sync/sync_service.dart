import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pool/pool.dart';

import '../../models/article.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/feed_repository.dart';
import '../logging/app_logger.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_store.dart';
import '../rss/feed_parser.dart';
import '../rss/rss_client.dart';
import '../rss/parsed_feed.dart';
import '../notifications/notification_service.dart';
import '../cache/article_cache_service.dart';
import '../extract/article_extractor.dart';
import '../../utils/keyword_filter.dart';
import '../logging/log_context.dart';
import 'effective_feed_settings.dart';
import 'sync_mutex.dart';
import 'sync_status_reporter.dart';

const int _parseInIsolateThreshold = 50000;

Map<String, Object?> _parseFeedInIsolate(String xml) {
  final parsed = FeedParser().parse(xml);
  return {
    'title': parsed.title,
    'siteUrl': parsed.siteUrl,
    'description': parsed.description,
    'items': parsed.items
        .map(
          (it) => {
            'remoteId': it.remoteId,
            'link': it.link,
            'title': it.title,
            'author': it.author,
            'publishedAt': it.publishedAt?.toIso8601String(),
            'contentHtml': it.contentHtml,
          },
        )
        .toList(growable: false),
  };
}

ParsedFeed _parsedFeedFromMap(Map<String, Object?> data) {
  final items = <ParsedItem>[];
  final rawItems = data['items'];
  if (rawItems is List) {
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final map = raw.cast<String, Object?>();
      final link = map['link'];
      if (link is! String || link.trim().isEmpty) continue;
      final publishedAt = map['publishedAt'];
      items.add(
        ParsedItem(
          remoteId: map['remoteId'] as String?,
          link: link,
          title: map['title'] as String?,
          author: map['author'] as String?,
          publishedAt: publishedAt is String
              ? DateTime.tryParse(publishedAt)
              : null,
          contentHtml: map['contentHtml'] as String?,
        ),
      );
    }
  }
  return ParsedFeed(
    title: data['title'] as String?,
    siteUrl: data['siteUrl'] as String?,
    description: data['description'] as String?,
    items: items,
  );
}

Map<String, Object?> _rssFeedFailureContext(
  Feed feed,
  Object error, {
  required int attempts,
  required int? durationMs,
  required int? statusCode,
}) {
  final extra = <String, Object?>{
    'attempts': attempts,
    'backend': 'rss',
    'durationMs': durationMs,
    'feedId': feed.id,
    'operation': 'refreshFeed',
    'statusCode': statusCode,
  };
  if (error is DioException) {
    return logContextForDioException(error, extra: extra);
  }
  final uri = Uri.tryParse(feed.url);
  if (uri == null) return extra;
  return logContextForUri(uri, method: 'GET', extra: extra);
}

class FeedRefreshResult {
  const FeedRefreshResult({
    required this.feedId,
    required this.incomingCount,
    required this.newCount,
    this.error,
  });

  final int feedId;
  final int incomingCount;
  final int newCount;
  final Object? error;

  bool get ok => error == null;
}

class BatchRefreshResult {
  const BatchRefreshResult(this.results);

  final List<FeedRefreshResult> results;

  int get okCount => results.where((r) => r.ok).length;
  int get errorCount => results.length - okCount;
  int get incomingTotal => results.fold(0, (sum, r) => sum + r.incomingCount);
  int get newTotal => results.fold(0, (sum, r) => sum + r.newCount);
  FeedRefreshResult? get firstError => results
      .cast<FeedRefreshResult?>()
      .firstWhere((r) => r?.error != null, orElse: () => null);
}

abstract class SyncServiceBase {
  Future<int> offlineCacheFeed(int feedId);

  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  });

  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  });
}

abstract class OutboxFlushCapable {
  Future<bool> flushOutboxSafe();
}

class SyncService implements SyncServiceBase {
  SyncService({
    required FeedRepository feeds,
    required CategoryRepository categories,
    required ArticleRepository articles,
    required RssClient client,
    required FeedParser parser,
    required NotificationService notifications,
    required ArticleCacheService cache,
    required ArticleExtractor extractor,
    required AppSettingsStore appSettingsStore,
    SyncStatusReporter? statusReporter,
  }) : _feeds = feeds,
       _categories = categories,
       _articles = articles,
       _client = client,
       _parser = parser,
       _notifications = notifications,
       _cache = cache,
       _extractor = extractor,
       _appSettingsStore = appSettingsStore,
       _statusReporter = statusReporter ?? const NoopSyncStatusReporter();

  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final ArticleRepository _articles;
  final RssClient _client;
  final FeedParser _parser;
  final NotificationService _notifications;
  final ArticleCacheService _cache;
  final ArticleExtractor _extractor;
  final AppSettingsStore _appSettingsStore;
  final SyncStatusReporter _statusReporter;
  Future<void> _batchRefreshQueue = Future.value();

  @override
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
    return EffectiveFeedSettings.resolve(feed, category, resolvedAppSettings);
  }

  Future<ParsedFeed> _parseFeed(String xml) async {
    if (xml.length < _parseInIsolateThreshold) {
      return _parser.parse(xml);
    }
    final data = await compute(_parseFeedInIsolate, xml);
    return _parsedFeedFromMap(data);
  }

  Future<_RefreshOutcome> _refreshFeedOnce(
    Feed feed,
    _EffectiveFeedSettings settings,
    AppSettings appSettings,
    bool notify,
  ) async {
    final feedId = feed.id;

    final fetched = await _client.fetchXml(
      feed.url,
      ifNoneMatch: feed.etag,
      ifModifiedSince: feed.lastModified,
      userAgent: settings.rssUserAgent,
    );

    final status = fetched.statusCode;
    if (status == 304) {
      return _RefreshOutcome(
        feedId: feedId,
        statusCode: 304,
        incomingCount: 0,
        newCount: 0,
        etag: fetched.etag,
        lastModified: fetched.lastModified,
      );
    }
    if (status != 200) {
      throw Exception('Feed fetch failed: HTTP $status');
    }

    final parsed = await _parseFeed(fetched.body);

    await _feeds.updateMeta(
      id: feedId,
      title: parsed.title,
      siteUrl: parsed.siteUrl,
      description: parsed.description,
      lastSyncedAt: DateTime.now(),
    );

    final filteredItems =
        (!settings.filterEnabled || settings.filterKeywords.trim().isEmpty)
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
            ..publishedAt =
                it.publishedAt?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return a;
        })
        .toList(growable: false);

    final newArticles = await _articles.upsertMany(feedId, incoming);

    // Best-effort offline caching for newly discovered articles.
    if (settings.syncImages && newArticles.isNotEmpty) {
      // Don't let caching failures break the refresh flow.
      try {
        await _cache.cacheArticles(newArticles);
      } catch (_) {}
    }

    // Best-effort full web page (readability) fetch for newly discovered articles.
    if (settings.syncWebPages && newArticles.isNotEmpty) {
      try {
        await _syncWebPagesForArticles(
          newArticles,
          webUserAgent: appSettings.webUserAgent,
          syncImages: settings.syncImages,
        );
      } catch (_) {}
    }

    if (notify && newArticles.isNotEmpty) {
      try {
        await _notifications.showNewArticlesNotification(
          newArticles,
          localeTag: appSettings.localeTag,
        );
      } catch (e) {
        // Don't let notification failures (permissions/plugin issues) break sync.
        AppLogger.w('Per-feed notification failed', tag: 'sync', error: e);
      }
    }

    return _RefreshOutcome(
      feedId: feedId,
      statusCode: 200,
      incomingCount: incoming.length,
      newCount: newArticles.length,
      etag: fetched.etag,
      lastModified: fetched.lastModified,
    );
  }

  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
    bool reportStatus = true,
  }) async {
    return SyncMutex.instance.run('sync', () async {
      final feed = await _feeds.getById(feedId);
      if (feed == null) {
        return FeedRefreshResult(
          feedId: feedId,
          incomingCount: 0,
          newCount: 0,
          error: ArgumentError('Feed $feedId not found'),
        );
      }

      SyncStatusTask? task;
      if (reportStatus) {
        final title = (feed.userTitle ?? feed.title ?? '').trim();
        task = _statusReporter.startTask(
          label: SyncStatusLabel.syncingFeeds,
          detail: title.isEmpty ? null : title,
        );
      }

      var success = false;
      try {
        final resolvedAppSettings =
            appSettings ?? await _appSettingsStore.load();
        final settings = await _resolveSettings(
          feed,
          appSettings: resolvedAppSettings,
        );
        if (!settings.syncEnabled) {
          // Skip network refresh when sync is disabled for this feed (effective).
          success = true;
          return FeedRefreshResult(
            feedId: feedId,
            incomingCount: 0,
            newCount: 0,
          );
        }

        Object? lastError;
        StackTrace? lastStack;
        int? lastDurationMs;
        int? lastStatusCode;
        final attempts = maxAttempts < 1 ? 1 : maxAttempts;
        final sw = Stopwatch()..start();
        for (var i = 0; i < attempts; i++) {
          final checkedAt = DateTime.now();
          try {
            final out = await _refreshFeedOnce(
              feed,
              settings,
              resolvedAppSettings,
              notify,
            );
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

            success = true;
            return FeedRefreshResult(
              feedId: feedId,
              incomingCount: out.incomingCount,
              newCount: out.newCount,
            );
          } catch (e, s) {
            lastError = e;
            lastStack = s;
            // Keep duration per attempt; store the last attempt duration.
            sw.stop();
            final statusCode = e is DioException
                ? e.response?.statusCode
                : null;
            lastDurationMs = sw.elapsedMilliseconds;
            lastStatusCode = statusCode;
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
        final error = lastError ?? Exception('Unknown sync error');
        AppLogger.w(
          'RSS feed refresh failed',
          tag: 'sync',
          error: error,
          stackTrace: lastStack,
          context: _rssFeedFailureContext(
            feed,
            error,
            attempts: attempts,
            durationMs: lastDurationMs,
            statusCode: lastStatusCode,
          ),
        );
        return FeedRefreshResult(
          feedId: feedId,
          incomingCount: 0,
          newCount: 0,
          error: error,
        );
      } catch (e, s) {
        // Guard against unexpected errors (settings load/category lookup, etc.)
        // so the "safe" API never leaks exceptions, and the status capsule never
        // gets stuck in a running state.
        AppLogger.w(
          'RSS feed refresh setup failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _rssFeedFailureContext(
            feed,
            e,
            attempts: maxAttempts < 1 ? 1 : maxAttempts,
            durationMs: null,
            statusCode: null,
          ),
        );
        return FeedRefreshResult(
          feedId: feedId,
          incomingCount: 0,
          newCount: 0,
          error: e,
        );
      } finally {
        task?.complete(success: success);
      }
    });
  }

  @override
  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  }) {
    return SyncMutex.instance.run('sync', () {
      final ids = feedIds.toList(growable: false);
      final task = _batchRefreshQueue.then((_) async {
        if (ids.isEmpty) return const BatchRefreshResult([]);

        final status = _statusReporter.startTask(
          label: SyncStatusLabel.syncingFeeds,
          current: 0,
          total: ids.length,
        );
        try {
          final batch = await _refreshFeedsSafeImpl(
            ids,
            maxConcurrent: maxConcurrent,
            maxAttemptsPerFeed: maxAttemptsPerFeed,
            onProgress: (current, total) {
              onProgress?.call(current, total);
              status.update(current: current, total: total);
            },
            notify: notify,
          );
          status.complete(success: batch.errorCount == 0);
          return batch;
        } catch (e) {
          status.complete(success: false);
          rethrow;
        }
      });
      _batchRefreshQueue = task.then((_) {}).catchError((_) {});
      return task;
    });
  }

  Future<BatchRefreshResult> _refreshFeedsSafeImpl(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    required bool notify,
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

    if (ids.length == 1) {
      final r = await refreshFeedSafe(
        ids.first,
        maxAttempts: maxAttemptsPerFeed,
        appSettings: appSettings,
        notify: notify,
        reportStatus: false,
      );
      return BatchRefreshResult([r]);
    }

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
              notify: false, // aggregate notification at the batch level
              reportStatus: false,
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

    final batch = BatchRefreshResult(results);
    if (notify && batch.newTotal > 0) {
      try {
        await _notifications.showNewArticlesSummaryNotification(
          batch.newTotal,
          localeTag: appSettings.localeTag,
        );
      } catch (e) {
        // Don't let notification failures (permissions/plugin issues) break sync.
        AppLogger.w('Summary notification failed', tag: 'sync', error: e);
      }
    }
    return batch;
  }

  static const int _maxWebPagesPerRefresh = 8;

  Future<void> _syncWebPagesForArticles(
    List<Article> articles, {
    required String webUserAgent,
    required bool syncImages,
  }) async {
    final pool = Pool(2);
    final targets = articles.length <= _maxWebPagesPerRefresh
        ? articles
        : articles.sublist(0, _maxWebPagesPerRefresh);

    final futures = <Future<void>>[];
    for (final a in targets) {
      futures.add(
        pool.withResource(() async {
          try {
            // Skip if already extracted (should be rare for "new" articles).
            if ((a.extractedContentHtml ?? '').trim().isNotEmpty) return;

            final extracted = await _extractor.extract(
              a.link,
              userAgent: webUserAgent,
            );
            if (extracted.contentHtml.trim().isEmpty) {
              // Mark failure only when we got an empty/invalid extraction result.
              await _articles.markExtractionFailed(a.id);
              return;
            }
            await _articles.setExtractedContent(a.id, extracted.contentHtml);

            if (syncImages) {
              await _cache.prefetchImagesFromHtml(
                extracted.contentHtml,
                baseUrl: Uri.tryParse(a.link),
                maxConcurrent: 3,
              );
            }
          } catch (_) {
            // Best-effort: don't persist failure for transient network errors.
          }
        }),
      );
    }

    await Future.wait(futures);
    await pool.close();
  }
}

class _RefreshOutcome {
  const _RefreshOutcome({
    required this.feedId,
    required this.statusCode,
    required this.incomingCount,
    required this.newCount,
    this.etag,
    this.lastModified,
  });

  final int feedId;
  final int statusCode;
  final int incomingCount;
  final int newCount;
  final String? etag;
  final String? lastModified;
}

typedef _EffectiveFeedSettings = EffectiveFeedSettings;
