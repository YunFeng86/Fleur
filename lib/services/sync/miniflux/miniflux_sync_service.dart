import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pool/pool.dart';

import '../../../models/article.dart';
import '../../../models/category.dart';
import '../../../models/feed.dart';
import '../../../repositories/article_repository.dart';
import '../../../repositories/category_repository.dart';
import '../../../repositories/feed_repository.dart';
import '../../accounts/account.dart';
import '../../accounts/credential_store.dart';
import '../../cache/article_cache_service.dart';
import '../../extract/article_extractor.dart';
import '../../logging/app_logger.dart';
import '../../logging/log_context.dart';
import '../../settings/app_settings.dart';
import '../../settings/app_settings_store.dart';
import '../effective_feed_settings.dart';
import '../outbox/outbox_store.dart';
import '../remote_article_action_executor.dart';
import '../remote_client_factory.dart';
import '../sync_service.dart';
import '../sync_mutex.dart';
import '../sync_status_reporter.dart';
import 'miniflux_client.dart';

class MinifluxSyncService implements SyncServiceBase, OutboxFlushCapable {
  MinifluxSyncService({
    required this.account,
    required Dio dio,
    required CredentialStore credentials,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required ArticleRepository articles,
    required OutboxStore outbox,
    required AppSettingsStore appSettingsStore,
    required ArticleCacheService cache,
    required ArticleExtractor extractor,
    SyncStatusReporter? statusReporter,
  }) : _clientFactory = RemoteClientFactory(dio: dio, credentials: credentials),
       _feeds = feeds,
       _categories = categories,
       _articles = articles,
       _outbox = outbox,
       _appSettingsStore = appSettingsStore,
       _cache = cache,
       _extractor = extractor,
       _statusReporter = statusReporter ?? const NoopSyncStatusReporter();

  final Account account;

  final RemoteClientFactory _clientFactory;
  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final ArticleRepository _articles;
  final OutboxStore _outbox;
  final AppSettingsStore _appSettingsStore;
  final ArticleCacheService _cache;
  final ArticleExtractor _extractor;
  final SyncStatusReporter _statusReporter;

  Map<String, Object?> _accountFailureContext(
    Object error, {
    required String operation,
    required int feedCount,
  }) {
    final extra = <String, Object?>{
      'accountId': account.id,
      'accountType': 'miniflux',
      'backend': 'miniflux',
      'feedCount': feedCount,
      'operation': operation,
    };
    if (error is DioException) {
      return logContextForDioException(error, extra: extra);
    }
    final baseUrl = account.baseUrl?.trim();
    final uri = baseUrl == null || baseUrl.isEmpty
        ? null
        : Uri.tryParse(baseUrl);
    if (uri == null) return extra;
    return logContextForUri(uri, extra: extra);
  }

  @override
  Future<int> offlineCacheFeed(int feedId) async {
    final feed = await _feeds.getById(feedId);
    if (feed == null) return 0;
    final appSettings = await _appSettingsStore.load();
    final settings = await _resolveSettings(feed, appSettings);
    final unread = await _articles.getUnread(feedId: feedId);

    // Best-effort: do not throw to callers.
    try {
      // If web pages are enabled, prefer extracting + caching from extracted HTML.
      if (settings.syncWebPages && unread.isNotEmpty) {
        MinifluxClient? client;
        final preferServerFetch =
            appSettings.minifluxWebFetchMode ==
            MinifluxWebFetchMode.serverFetchContent;
        if (preferServerFetch) {
          try {
            client = await _buildClient();
          } catch (_) {
            client = null;
          }
        }
        await _syncWebPagesForArticles(
          unread,
          client: client,
          preferServerFetch: preferServerFetch,
          webUserAgent: appSettings.webUserAgent,
          syncImages: settings.syncImages,
        );
      }
      if (settings.syncImages && unread.isNotEmpty) {
        return await _cache.cacheArticles(unread);
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  }) async {
    final batch = await refreshFeedsSafe([feedId], notify: notify);
    return batch.results.isEmpty
        ? FeedRefreshResult(feedId: feedId, incomingCount: 0, newCount: 0)
        : batch.results.first;
  }

  @override
  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  }) async {
    return SyncMutex.instance.run('sync', () async {
      // For Miniflux, syncing is not "per local feed"; we sync the account once.
      final status = _statusReporter.startTask(
        label: SyncStatusLabel.syncing,
        detail: account.name.trim().isEmpty ? null : account.name.trim(),
      );
      try {
        await syncNow(status: status);
        final total = feedIds.length;
        onProgress?.call(total, total);
        status.complete(success: true);
        return BatchRefreshResult([
          FeedRefreshResult(
            feedId: feedIds.isEmpty ? -1 : feedIds.first,
            incomingCount: 0,
            newCount: 0,
          ),
        ]);
      } catch (e, s) {
        final total = feedIds.length;
        onProgress?.call(total, total);
        status.complete(success: false);
        AppLogger.w(
          'Miniflux account sync failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _accountFailureContext(
            e,
            operation: 'refreshAccount',
            feedCount: total,
          ),
        );
        return BatchRefreshResult([
          FeedRefreshResult(
            feedId: feedIds.isEmpty ? -1 : feedIds.first,
            incomingCount: 0,
            newCount: 0,
            error: e,
          ),
        ]);
      }
    });
  }

  Future<void> syncNow({int? entriesLimit, SyncStatusTask? status}) async {
    final client = await _buildClient();
    status?.update(label: SyncStatusLabel.uploadingChanges);
    await _flushOutbox(client);
    final appSettings = await _appSettingsStore.load();
    final effectiveEntriesLimit =
        entriesLimit ?? appSettings.remoteEntriesLimit;
    final preferServerFetch =
        appSettings.minifluxWebFetchMode ==
        MinifluxWebFetchMode.serverFetchContent;

    final cats = await client.getCategories();
    final remoteCatIdToLocalId = <int, int>{};
    for (final c in cats) {
      final id = c['id'];
      final title = c['title'];
      if (id is! int || title is! String) continue;
      final localId = await _categories.upsertByName(title);
      remoteCatIdToLocalId[id] = localId;
    }

    status?.update(label: SyncStatusLabel.syncingSubscriptions);
    final feeds = await client.getFeeds();
    status?.update(
      label: SyncStatusLabel.syncingSubscriptions,
      current: 0,
      total: feeds.length,
    );
    final remoteFeedIdToLocalFeed = <int, Feed>{};
    final localFeedIdToFeed = <int, Feed>{};
    final localFeedIdToSettings = <int, EffectiveFeedSettings>{};
    var feedProcessed = 0;
    for (final f in feeds) {
      feedProcessed += 1;
      status?.update(current: feedProcessed, total: feeds.length);
      final id = f['id'];
      final feedUrl = f['feed_url'];
      if (id is! int || feedUrl is! String) continue;
      final localId = await _feeds.upsertUrl(feedUrl);
      final categoryId = f['category'] is Map
          ? (f['category'] as Map)['id']
          : f['category_id'];
      int? localCatId;
      if (categoryId is int) localCatId = remoteCatIdToLocalId[categoryId];
      if (localCatId != null) {
        await _feeds.setCategory(feedId: localId, categoryId: localCatId);
      }
      final local = await _feeds.getById(localId);
      if (local != null) {
        final settings = await _resolveSettings(local, appSettings);
        await _feeds.updateMeta(
          id: local.id,
          title: f['title'] as String?,
          siteUrl: f['site_url'] as String?,
          description: f['description'] as String?,
          lastSyncedAt: settings.syncEnabled ? DateTime.now() : null,
        );
        remoteFeedIdToLocalFeed[id] = local;
        localFeedIdToFeed[local.id] = local;
        localFeedIdToSettings[local.id] = settings;
      }
    }

    // 0 means "unlimited": paginate until server has no more entries.
    if (effectiveEntriesLimit == 0) {
      const pageSize = 1000;
      var offset = 0;
      status?.update(
        label: SyncStatusLabel.syncingUnreadArticles,
        current: 0,
        total: null,
      );
      while (true) {
        final r = await _syncEntriesBatch(
          client,
          appSettings,
          remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
          localFeedIdToFeed: localFeedIdToFeed,
          localFeedIdToSettings: localFeedIdToSettings,
          limit: pageSize,
          offset: offset,
          preferServerFetch: preferServerFetch,
        );
        if (r.processed == 0) break;
        offset += r.processed;
        status?.update(current: offset, total: r.total);
        if (r.total != null && offset >= r.total!) break;
        if (r.processed < pageSize) break;

        // Yield to the event loop between pages to keep the app responsive on
        // very large imports (tens of thousands of entries).
        await Future<void>.delayed(Duration.zero);
      }
      return;
    }

    if (effectiveEntriesLimit < 0) return;
    status?.update(
      label: SyncStatusLabel.syncingUnreadArticles,
      current: 0,
      total: effectiveEntriesLimit,
    );
    final r = await _syncEntriesBatch(
      client,
      appSettings,
      remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
      localFeedIdToFeed: localFeedIdToFeed,
      localFeedIdToSettings: localFeedIdToSettings,
      limit: effectiveEntriesLimit,
      offset: 0,
      preferServerFetch: preferServerFetch,
    );
    status?.update(
      current: r.processed,
      total: r.total ?? effectiveEntriesLimit,
    );
  }

  Future<({int processed, int? total})> _syncEntriesBatch(
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required int limit,
    required int offset,
    required bool preferServerFetch,
  }) async {
    if (limit <= 0) return (processed: 0, total: null);
    final resp = await client.getEntries(limit: limit, offset: offset);
    final raw = resp['entries'];
    final totalRaw = resp['total'];
    final total = totalRaw is int ? totalRaw : null;
    if (raw is! List) return (processed: 0, total: total);

    // Group by local feed id for ArticleRepository.upsertMany() calls.
    final byLocalFeedId = <int, List<Article>>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final m = e.cast<String, Object?>();
      final remoteEntryId = m['id'];
      final remoteFeedId = m['feed_id'];
      if (remoteEntryId is! int || remoteFeedId is! int) continue;
      final localFeed = remoteFeedIdToLocalFeed[remoteFeedId];
      if (localFeed == null) continue;
      final effectiveSettings = localFeedIdToSettings[localFeed.id];
      if (effectiveSettings != null && !effectiveSettings.syncEnabled) continue;

      final url = m['url'] as String? ?? '';
      if (url.trim().isEmpty) continue;

      final status = m['status'] as String?;
      final isRead = status == 'read';
      final starred = m['starred'] == true;

      final publishedAt =
          _parseEpochSeconds(m['published_at']) ??
          _parseIso(m['published_at']) ??
          _parseIso(m['created_at']);

      final content = m['content'];
      final contentHtml = (content is String) ? content : null;

      final a = Article()
        ..remoteId = remoteEntryId.toString()
        ..link = url
        ..title = m['title'] as String?
        ..author = null
        ..contentHtml = contentHtml
        ..publishedAt = (publishedAt ?? DateTime.now().toUtc())
        ..isRead = isRead
        ..isStarred = starred;

      byLocalFeedId.putIfAbsent(localFeed.id, () => []).add(a);
    }

    var feedGroupsProcessed = 0;
    for (final entry in byLocalFeedId.entries) {
      // Remote-backed: we want remote read/star state to be authoritative.
      final newArticles = await _articles.upsertMany(
        entry.key,
        entry.value,
        preserveUserState: false,
      );

      // Best-effort offline "inventory": cache/extract newly discovered items.
      if (newArticles.isNotEmpty) {
        final feed =
            localFeedIdToFeed[entry.key] ?? await _feeds.getById(entry.key);
        if (feed != null) {
          final settings =
              localFeedIdToSettings[feed.id] ??
              await _resolveSettings(feed, appSettings);
          await _prefetchNewArticles(
            newArticles,
            settings,
            appSettings,
            client: client,
            preferServerFetch: preferServerFetch,
          );
        }
      }

      // Don't hog the UI isolate when a batch fans out to many feeds.
      feedGroupsProcessed += 1;
      if (byLocalFeedId.length > 8 && feedGroupsProcessed % 5 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return (processed: raw.length, total: total);
  }

  @override
  Future<bool> flushOutboxSafe() async {
    return SyncMutex.instance.run('sync', () async {
      try {
        final client = await _buildClient();
        await _flushOutbox(client);
        return true;
      } catch (e, s) {
        AppLogger.w(
          'Miniflux outbox flush failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _outboxFailureContext(e, operation: 'flushOutboxSafe'),
        );
        return false;
      }
    });
  }

  Future<MinifluxClient> _buildClient() async {
    return _clientFactory.miniflux(account);
  }

  Future<void> _flushOutbox(MinifluxClient client) async {
    final pending = await _outbox.load(account.id);
    if (pending.isEmpty) return;

    final executor = MinifluxRemoteArticleActionExecutor(client);
    final remaining = <OutboxAction>[];
    for (final a in pending) {
      try {
        await executor.apply(a);
      } catch (e, s) {
        AppLogger.w(
          'Miniflux outbox action failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _outboxFailureContext(
            e,
            operation: 'flushOutbox',
            action: a,
          ),
        );
        remaining.add(a);
      }
    }

    if (remaining.length != pending.length) {
      await _outbox.save(account.id, remaining);
    }
  }

  Map<String, Object?> _outboxFailureContext(
    Object error, {
    required String operation,
    OutboxAction? action,
  }) {
    final extra = <String, Object?>{
      'accountId': account.id,
      'accountType': 'miniflux',
      'backend': 'miniflux',
      'operation': operation,
      if (action != null) ...<String, Object?>{
        'actionType': action.type.wire,
        'remoteEntryIdPresent': action.remoteEntryId != null,
        'feedUrlPresent': (action.feedUrl ?? '').trim().isNotEmpty,
        'categoryTitlePresent': (action.categoryTitle ?? '').trim().isNotEmpty,
      },
    };
    if (error is DioException) {
      return logContextForDioException(error, extra: extra);
    }
    final baseUrl = account.baseUrl?.trim();
    final uri = baseUrl == null || baseUrl.isEmpty
        ? null
        : Uri.tryParse(baseUrl);
    if (uri == null) return extra;
    return logContextForUri(uri, extra: extra);
  }

  static DateTime? _parseEpochSeconds(Object? v) {
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
    }
    return null;
  }

  static DateTime? _parseIso(Object? v) {
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  Future<EffectiveFeedSettings> _resolveSettings(
    Feed feed,
    AppSettings appSettings,
  ) async {
    final categoryId = feed.categoryId;
    final Category? category = categoryId == null
        ? null
        : await _categories.getById(categoryId);
    return EffectiveFeedSettings.resolve(feed, category, appSettings);
  }

  Future<void> _prefetchNewArticles(
    List<Article> newArticles,
    EffectiveFeedSettings settings,
    AppSettings appSettings, {
    required MinifluxClient client,
    required bool preferServerFetch,
  }) async {
    // Best-effort prefetch; do not break sync flow.
    if (newArticles.isEmpty) return;

    // Mirror local SyncService behavior: cache feed/extracted images first.
    if (settings.syncImages) {
      try {
        // Avoid accidental long stalls when syncing a large batch.
        const maxArticles = 30;
        final targets = newArticles.length <= maxArticles
            ? newArticles
            : newArticles.sublist(0, maxArticles);
        await _cache.cacheArticles(targets);
      } catch (_) {}
    }

    if (settings.syncWebPages) {
      try {
        await _syncWebPagesForArticles(
          newArticles,
          client: client,
          preferServerFetch: preferServerFetch,
          webUserAgent: appSettings.webUserAgent,
          syncImages: settings.syncImages,
        );
      } catch (_) {}
    }
  }

  static const int _maxWebPagesPerSync = 8;

  Future<void> _syncWebPagesForArticles(
    List<Article> articles, {
    required MinifluxClient? client,
    required bool preferServerFetch,
    required String webUserAgent,
    required bool syncImages,
  }) async {
    final pool = Pool(2);
    final targets = articles.length <= _maxWebPagesPerSync
        ? articles
        : articles.sublist(0, _maxWebPagesPerSync);

    final futures = <Future<void>>[];
    for (final a in targets) {
      futures.add(
        pool.withResource(() async {
          try {
            // Skip if already extracted (common when re-syncing the same window).
            if ((a.extractedContentHtml ?? '').trim().isNotEmpty) return;

            String html = '';
            if (preferServerFetch && client != null) {
              final rid = int.tryParse((a.remoteId ?? '').trim());
              if (rid != null) {
                html = await client.fetchEntryContent(rid);
              }
            }
            if (html.trim().isEmpty) {
              final extracted = await _extractor.extract(
                a.link,
                userAgent: webUserAgent,
              );
              html = extracted.contentHtml;
            }

            if (html.trim().isEmpty) {
              await _articles.markExtractionFailed(a.id);
              return;
            }
            await _articles.setExtractedContent(a.id, html);

            if (syncImages) {
              await _cache.prefetchImagesFromHtml(
                html,
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
