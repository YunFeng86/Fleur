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

typedef _MinifluxEntriesPage = ({
  int limit,
  int offset,
  List<Object?> entries,
  int processed,
  int? total,
});

class _EntriesSyncCounts {
  const _EntriesSyncCounts({
    required this.incomingCount,
    required this.newCount,
  });

  static const zero = _EntriesSyncCounts(incomingCount: 0, newCount: 0);

  final int incomingCount;
  final int newCount;

  _EntriesSyncCounts plus(_EntriesSyncCounts other) {
    return _EntriesSyncCounts(
      incomingCount: incomingCount + other.incomingCount,
      newCount: newCount + other.newCount,
    );
  }
}

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

  static const int _entriesPageSize = 200;

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
    final ids = feedIds.toList(growable: false);
    if (ids.isEmpty) {
      onProgress?.call(0, 0);
      return const BatchRefreshResult([]);
    }

    return SyncMutex.instance.run('sync', () async {
      final status = _statusReporter.startTask(
        label: SyncStatusLabel.syncingFeeds,
        current: 0,
        total: ids.length,
      );
      final client = await _buildClient();
      try {
        await _flushOutbox(client);
        final appSettings = await _appSettingsStore.load();
        final preferServerFetch =
            appSettings.minifluxWebFetchMode ==
            MinifluxWebFetchMode.serverFetchContent;
        final pool = Pool(maxConcurrent < 1 ? 1 : maxConcurrent);
        final results = List<FeedRefreshResult?>.filled(ids.length, null);
        var completed = 0;
        try {
          await Future.wait([
            for (var i = 0; i < ids.length; i += 1)
              pool.withResource(() async {
                final result = await _refreshRemoteFeedEntries(
                  client,
                  feedId: ids[i],
                  appSettings: appSettings,
                  preferServerFetch: preferServerFetch,
                  status: ids.length == 1 ? status : null,
                );
                results[i] = result;
                completed += 1;
                onProgress?.call(completed, ids.length);
                status.update(current: completed, total: ids.length);
              }),
          ]);
        } finally {
          await pool.close();
        }
        final batch = BatchRefreshResult(
          results.whereType<FeedRefreshResult>().toList(),
        );
        status.complete(success: batch.errorCount == 0);
        return batch;
      } catch (e, s) {
        onProgress?.call(ids.length, ids.length);
        status.complete(success: false);
        AppLogger.w(
          'Miniflux scoped feed sync failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _accountFailureContext(
            e,
            operation: 'refreshScopedFeeds',
            feedCount: ids.length,
          ),
        );
        return BatchRefreshResult([
          FeedRefreshResult(
            feedId: ids.first,
            incomingCount: 0,
            newCount: 0,
            error: e,
          ),
        ]);
      }
    });
  }

  @override
  Future<BatchRefreshResult> syncAccountSafe({
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    Iterable<int>? feedIds,
  }) async {
    return SyncMutex.instance.run('sync', () async {
      final ids = feedIds?.toList(growable: false) ?? const <int>[];
      final status = _statusReporter.startTask(
        label: SyncStatusLabel.syncing,
        detail: account.name.trim().isEmpty ? null : account.name.trim(),
      );
      try {
        await syncNow(status: status);
        final total = ids.length;
        onProgress?.call(total, total);
        status.complete(success: true);
        return BatchRefreshResult([
          FeedRefreshResult(
            feedId: ids.isEmpty ? -1 : ids.first,
            incomingCount: 0,
            newCount: 0,
          ),
        ]);
      } catch (e, s) {
        final total = ids.length;
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
            feedId: ids.isEmpty ? -1 : ids.first,
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
    final seenCategoryRemoteIds = <String>{};
    final protectedCategoryRemoteIds = <String>{};
    final categoryListTrustworthy =
        cats.isNotEmpty || !await _categories.hasRemoteMirrors();
    for (final c in cats) {
      final id = c['id'];
      final title = c['title'];
      if (id is! int || title is! String) continue;
      final remoteId = id.toString();
      final result = await _categories.upsertRemoteDetailed(
        remoteId: remoteId,
        name: title,
      );
      if (result.isBound) {
        seenCategoryRemoteIds.add(remoteId);
        remoteCatIdToLocalId[id] = result.localId;
      } else {
        final protectedId = result.effectiveRemoteId;
        if (protectedId != null && protectedId.isNotEmpty) {
          protectedCategoryRemoteIds.add(protectedId);
        }
      }
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
    final seenFeedRemoteIds = <String>{};
    final protectedFeedRemoteIds = <String>{};
    final feedMirrorIndex = await _feeds.createRemoteMirrorIndex();
    var feedProcessed = 0;
    for (final f in feeds) {
      feedProcessed += 1;
      status?.update(current: feedProcessed, total: feeds.length);
      final id = f['id'];
      final feedUrl = f['feed_url'];
      if (id is! int || feedUrl is! String) continue;
      final remoteId = id.toString();
      final categoryId = f['category'] is Map
          ? (f['category'] as Map)['id']
          : f['category_id'];
      int? localCatId;
      var updateCategory = true;
      if (categoryId is int) {
        localCatId = remoteCatIdToLocalId[categoryId];
        if (localCatId == null && f['category'] is Map) {
          final remoteCategory = f['category'] as Map;
          final remoteCategoryTitle = (remoteCategory['title'] as String?)
              ?.trim();
          if (remoteCategoryTitle != null && remoteCategoryTitle.isNotEmpty) {
            final categoryResult = await _categories.upsertRemoteDetailed(
              remoteId: categoryId.toString(),
              name: remoteCategoryTitle,
            );
            if (categoryResult.isBound) {
              localCatId = categoryResult.localId;
              remoteCatIdToLocalId[categoryId] = categoryResult.localId;
            } else {
              final protectedId = categoryResult.effectiveRemoteId;
              if (protectedId != null && protectedId.isNotEmpty) {
                protectedCategoryRemoteIds.add(protectedId);
              }
            }
          }
        }
        updateCategory = localCatId != null;
      }
      final result = await _feeds.upsertRemoteDetailed(
        remoteId: remoteId,
        url: feedUrl,
        title: f['title'] as String?,
        siteUrl: f['site_url'] as String?,
        description: f['description'] as String?,
        categoryId: localCatId,
        updateCategory: updateCategory,
        lookupIndex: feedMirrorIndex,
      );
      if (!result.isBound) {
        final protectedId = result.effectiveRemoteId;
        if (protectedId != null && protectedId.isNotEmpty) {
          protectedFeedRemoteIds.add(protectedId);
        }
        continue;
      }
      seenFeedRemoteIds.add(remoteId);
      final local = await _feeds.getById(result.localId);
      if (local != null) {
        final settings = await _resolveSettings(local, appSettings);
        await _feeds.updateMeta(
          id: local.id,
          lastSyncedAt: settings.syncEnabled ? DateTime.now() : null,
        );
        final refreshed = await _feeds.getById(local.id);
        if (refreshed == null) continue;
        remoteFeedIdToLocalFeed[id] = refreshed;
        localFeedIdToFeed[refreshed.id] = refreshed;
        localFeedIdToSettings[local.id] = settings;
      }
    }
    final allowFeedProtectedOnlyPrune =
        feeds.isNotEmpty &&
        seenFeedRemoteIds.isEmpty &&
        protectedFeedRemoteIds.isNotEmpty;
    final allowCategoryProtectedOnlyPrune =
        categoryListTrustworthy &&
        cats.isNotEmpty &&
        seenCategoryRemoteIds.isEmpty &&
        protectedCategoryRemoteIds.isNotEmpty;
    await _feeds.deleteRemoteMissing(
      seenFeedRemoteIds,
      allowEmptyPrune: allowFeedProtectedOnlyPrune,
      protectedRemoteIds: protectedFeedRemoteIds,
    );
    await _categories.deleteRemoteMissing(
      categoryListTrustworthy ? seenCategoryRemoteIds : const <String>{},
      allowEmptyPrune: allowCategoryProtectedOnlyPrune,
      protectedRemoteIds: protectedCategoryRemoteIds,
    );

    if (effectiveEntriesLimit == 0) {
      await _syncUnlimitedEntries(
        client,
        appSettings,
        remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
        localFeedIdToFeed: localFeedIdToFeed,
        localFeedIdToSettings: localFeedIdToSettings,
        preferServerFetch: preferServerFetch,
        status: status,
      );
      return;
    }

    if (effectiveEntriesLimit < 0) return;
    await _syncLimitedEntries(
      client,
      appSettings,
      remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
      localFeedIdToFeed: localFeedIdToFeed,
      localFeedIdToSettings: localFeedIdToSettings,
      entriesLimit: effectiveEntriesLimit,
      preferServerFetch: preferServerFetch,
      status: status,
    );
  }

  Future<FeedRefreshResult> _refreshRemoteFeedEntries(
    MinifluxClient client, {
    required int feedId,
    required AppSettings appSettings,
    required bool preferServerFetch,
    SyncStatusTask? status,
  }) async {
    final feed = await _feeds.getById(feedId);
    if (feed == null) {
      return FeedRefreshResult(
        feedId: feedId,
        incomingCount: 0,
        newCount: 0,
        error: ArgumentError('Feed $feedId not found'),
      );
    }

    final remoteFeedId = int.tryParse((feed.remoteId ?? '').trim());
    if (remoteFeedId == null || remoteFeedId <= 0) {
      return FeedRefreshResult(
        feedId: feedId,
        incomingCount: 0,
        newCount: 0,
        error: StateError('Remote feed id is missing for feed $feedId'),
      );
    }

    final checkedAt = DateTime.now();
    final sw = Stopwatch()..start();
    try {
      final settings = await _resolveSettings(feed, appSettings);
      if (!settings.syncEnabled) {
        await _feeds.updateSyncState(
          id: feedId,
          lastCheckedAt: checkedAt,
          lastDurationMs: sw.elapsedMilliseconds,
          lastIncomingCount: 0,
          clearError: true,
        );
        return FeedRefreshResult(feedId: feedId, incomingCount: 0, newCount: 0);
      }

      final remoteFeedIdToLocalFeed = <int, Feed>{remoteFeedId: feed};
      final localFeedIdToFeed = <int, Feed>{feed.id: feed};
      final localFeedIdToSettings = <int, EffectiveFeedSettings>{
        feed.id: settings,
      };
      final entriesLimit = appSettings.remoteEntriesLimit;
      final counts = entriesLimit == 0
          ? await _syncUnlimitedEntries(
              client,
              appSettings,
              remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
              localFeedIdToFeed: localFeedIdToFeed,
              localFeedIdToSettings: localFeedIdToSettings,
              preferServerFetch: preferServerFetch,
              status: status,
              remoteFeedId: remoteFeedId,
            )
          : entriesLimit < 0
          ? _EntriesSyncCounts.zero
          : await _syncLimitedEntries(
              client,
              appSettings,
              remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
              localFeedIdToFeed: localFeedIdToFeed,
              localFeedIdToSettings: localFeedIdToSettings,
              entriesLimit: entriesLimit,
              preferServerFetch: preferServerFetch,
              status: status,
              remoteFeedId: remoteFeedId,
            );

      sw.stop();
      await _feeds.updateMeta(id: feedId, lastSyncedAt: DateTime.now());
      await _feeds.updateSyncState(
        id: feedId,
        lastCheckedAt: checkedAt,
        lastDurationMs: sw.elapsedMilliseconds,
        lastIncomingCount: counts.incomingCount,
        clearError: true,
      );
      return FeedRefreshResult(
        feedId: feedId,
        incomingCount: counts.incomingCount,
        newCount: counts.newCount,
      );
    } catch (e, s) {
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
      AppLogger.w(
        'Miniflux scoped feed entries sync failed',
        tag: 'sync',
        error: e,
        stackTrace: s,
        context: _accountFailureContext(
          e,
          operation: 'refreshScopedFeedEntries',
          feedCount: 1,
        ),
      );
      return FeedRefreshResult(
        feedId: feedId,
        incomingCount: 0,
        newCount: 0,
        error: e,
      );
    }
  }

  Future<_EntriesSyncCounts> _syncLimitedEntries(
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required int entriesLimit,
    required bool preferServerFetch,
    SyncStatusTask? status,
    int? remoteFeedId,
  }) async {
    if (entriesLimit <= 0) return _EntriesSyncCounts.zero;
    status?.update(
      label: SyncStatusLabel.syncingUnreadArticles,
      current: 0,
      total: entriesLimit,
    );

    final firstLimit = _pageLimit(offset: 0, targetTotal: entriesLimit);
    final firstPage = await _fetchEntriesPage(
      client,
      limit: firstLimit,
      offset: 0,
      remoteFeedId: remoteFeedId,
    );
    final targetTotal = firstPage.total == null
        ? entriesLimit
        : _minInt(entriesLimit, firstPage.total!);

    var counts = await _processEntriesPage(
      firstPage,
      client,
      appSettings,
      remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
      localFeedIdToFeed: localFeedIdToFeed,
      localFeedIdToSettings: localFeedIdToSettings,
      preferServerFetch: preferServerFetch,
      status: status,
      progressTotal: targetTotal,
    );
    if (firstPage.processed == 0 || firstPage.processed < firstPage.limit) {
      return counts;
    }

    counts = counts.plus(
      await _syncKnownOffsetPages(
        client,
        appSettings,
        remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
        localFeedIdToFeed: localFeedIdToFeed,
        localFeedIdToSettings: localFeedIdToSettings,
        startOffset: firstPage.limit,
        targetTotal: targetTotal,
        preferServerFetch: preferServerFetch,
        status: status,
        remoteFeedId: remoteFeedId,
      ),
    );
    return counts;
  }

  Future<_EntriesSyncCounts> _syncUnlimitedEntries(
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required bool preferServerFetch,
    SyncStatusTask? status,
    int? remoteFeedId,
  }) async {
    status?.update(
      label: SyncStatusLabel.syncingUnreadArticles,
      current: 0,
      total: null,
    );
    final firstPage = await _fetchEntriesPage(
      client,
      limit: _entriesPageSize,
      offset: 0,
      remoteFeedId: remoteFeedId,
    );
    var counts = await _processEntriesPage(
      firstPage,
      client,
      appSettings,
      remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
      localFeedIdToFeed: localFeedIdToFeed,
      localFeedIdToSettings: localFeedIdToSettings,
      preferServerFetch: preferServerFetch,
      status: status,
      progressTotal: firstPage.total,
    );
    if (firstPage.processed == 0 || firstPage.processed < firstPage.limit) {
      return counts;
    }

    final total = firstPage.total;
    if (total == null) {
      counts = counts.plus(
        await _syncUnknownTotalSerialPages(
          client,
          appSettings,
          remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
          localFeedIdToFeed: localFeedIdToFeed,
          localFeedIdToSettings: localFeedIdToSettings,
          startOffset: firstPage.processed,
          preferServerFetch: preferServerFetch,
          status: status,
          remoteFeedId: remoteFeedId,
        ),
      );
      return counts;
    }

    counts = counts.plus(
      await _syncKnownOffsetPages(
        client,
        appSettings,
        remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
        localFeedIdToFeed: localFeedIdToFeed,
        localFeedIdToSettings: localFeedIdToSettings,
        startOffset: firstPage.limit,
        targetTotal: total,
        preferServerFetch: preferServerFetch,
        status: status,
        remoteFeedId: remoteFeedId,
      ),
    );
    return counts;
  }

  Future<_EntriesSyncCounts> _syncKnownOffsetPages(
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required int startOffset,
    required int targetTotal,
    required bool preferServerFetch,
    SyncStatusTask? status,
    int? remoteFeedId,
  }) async {
    final remoteFetchConcurrency = appSettings.remoteFetchConcurrency
        .clamp(1, 4)
        .toInt();
    var offset = startOffset;
    var counts = _EntriesSyncCounts.zero;
    while (offset < targetTotal) {
      final window = <Future<_MinifluxEntriesPage>>[];
      for (
        var i = 0;
        i < remoteFetchConcurrency && offset < targetTotal;
        i += 1
      ) {
        final limit = _pageLimit(offset: offset, targetTotal: targetTotal);
        window.add(
          _fetchEntriesPage(
            client,
            limit: limit,
            offset: offset,
            remoteFeedId: remoteFeedId,
          ),
        );
        offset += limit;
      }

      final pages = await Future.wait(window);
      var stop = false;
      for (final page in pages) {
        if (stop) break;
        counts = counts.plus(
          await _processEntriesPage(
            page,
            client,
            appSettings,
            remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
            localFeedIdToFeed: localFeedIdToFeed,
            localFeedIdToSettings: localFeedIdToSettings,
            preferServerFetch: preferServerFetch,
            status: status,
            progressTotal: targetTotal,
          ),
        );
        stop = page.processed == 0 || page.processed < page.limit;
      }
      if (stop) return counts;

      // Yield between windows when syncing large accounts.
      await Future<void>.delayed(Duration.zero);
    }
    return counts;
  }

  Future<_EntriesSyncCounts> _syncUnknownTotalSerialPages(
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required int startOffset,
    required bool preferServerFetch,
    SyncStatusTask? status,
    int? remoteFeedId,
  }) async {
    var offset = startOffset;
    var counts = _EntriesSyncCounts.zero;
    while (true) {
      final page = await _fetchEntriesPage(
        client,
        limit: _entriesPageSize,
        offset: offset,
        remoteFeedId: remoteFeedId,
      );
      counts = counts.plus(
        await _processEntriesPage(
          page,
          client,
          appSettings,
          remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
          localFeedIdToFeed: localFeedIdToFeed,
          localFeedIdToSettings: localFeedIdToSettings,
          preferServerFetch: preferServerFetch,
          status: status,
          progressTotal: null,
        ),
      );
      if (page.processed == 0 || page.processed < page.limit) return counts;
      offset += page.processed;

      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<_MinifluxEntriesPage> _fetchEntriesPage(
    MinifluxClient client, {
    required int limit,
    required int offset,
    int? remoteFeedId,
  }) async {
    final resp = remoteFeedId == null
        ? await client.getEntries(limit: limit, offset: offset)
        : await client.getFeedEntries(
            feedId: remoteFeedId,
            limit: limit,
            offset: offset,
          );
    final raw = resp['entries'];
    final totalRaw = resp['total'];
    final total = totalRaw is int ? totalRaw : null;
    final entries = raw is List ? raw.cast<Object?>() : const <Object?>[];
    return (
      limit: limit,
      offset: offset,
      entries: entries,
      processed: entries.length,
      total: total,
    );
  }

  Future<_EntriesSyncCounts> _processEntriesPage(
    _MinifluxEntriesPage page,
    MinifluxClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required bool preferServerFetch,
    SyncStatusTask? status,
    required int? progressTotal,
  }) async {
    final progressCurrent = page.offset + page.processed;
    status?.update(
      current: progressCurrent,
      total: progressTotal ?? page.total ?? progressCurrent,
    );

    if (page.entries.isEmpty) return _EntriesSyncCounts.zero;

    // Group by local feed id for ArticleRepository.upsertMany() calls.
    final byLocalFeedId = <int, List<Article>>{};
    for (final e in page.entries) {
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
    var newCount = 0;
    for (final entry in byLocalFeedId.entries) {
      // Remote-backed: we want remote read/star state to be authoritative.
      final newArticles = await _articles.upsertMany(
        entry.key,
        entry.value,
        preserveUserState: false,
      );
      newCount += newArticles.length;

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
    return _EntriesSyncCounts(
      incomingCount: byLocalFeedId.values.fold(
        0,
        (sum, items) => sum + items.length,
      ),
      newCount: newCount,
    );
  }

  static int _pageLimit({required int offset, required int targetTotal}) {
    final remaining = targetTotal - offset;
    if (remaining <= 0) return 0;
    return remaining < _entriesPageSize ? remaining : _entriesPageSize;
  }

  static int _minInt(int a, int b) => a < b ? a : b;

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

            late final String html;
            if (preferServerFetch) {
              if (client == null) {
                throw StateError('Miniflux client is unavailable');
              }
              final rid = int.tryParse((a.remoteId ?? '').trim());
              if (rid == null) {
                throw StateError('Miniflux entry id is missing');
              }
              html = await client.fetchEntryContent(rid);
            } else {
              final extracted = await _extractor.extract(
                a.link,
                userAgent: webUserAgent,
                expectedTitle: a.title,
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
