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
import '../../notifications/notification_service.dart';
import '../../settings/app_settings.dart';
import '../../settings/app_settings_store.dart';
import '../effective_feed_settings.dart';
import '../outbox/outbox_store.dart';
import '../remote_article_action_executor.dart';
import '../remote_client_factory.dart';
import '../sync_service.dart';
import '../sync_mutex.dart';
import '../sync_status_reporter.dart';
import '../../../utils/keyword_filter.dart';
import 'fever_client.dart';

class FeverSyncService implements SyncServiceBase, OutboxFlushCapable {
  FeverSyncService({
    required this.account,
    required Dio dio,
    required CredentialStore credentials,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required ArticleRepository articles,
    required OutboxStore outbox,
    required AppSettingsStore appSettingsStore,
    required NotificationService notifications,
    required ArticleCacheService cache,
    required ArticleExtractor extractor,
    SyncStatusReporter? statusReporter,
  }) : _clientFactory = RemoteClientFactory(dio: dio, credentials: credentials),
       _feeds = feeds,
       _categories = categories,
       _articles = articles,
       _outbox = outbox,
       _appSettingsStore = appSettingsStore,
       _notifications = notifications,
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
  final NotificationService _notifications;
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
      'accountType': account.type.wire,
      'backend': 'fever',
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

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  @override
  Future<int> offlineCacheFeed(int feedId) async {
    final unread = await _articles.getUnread(feedId: feedId);
    return _cache.cacheArticles(unread);
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
      final status = _statusReporter.startTask(
        label: SyncStatusLabel.syncing,
        detail: account.name.trim().isEmpty ? null : account.name.trim(),
      );
      try {
        await syncNow(status: status, notify: notify);
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
          'Fever account sync failed',
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

  Future<void> syncNow({SyncStatusTask? status, bool notify = true}) async {
    final client = await _buildClient();
    status?.update(label: SyncStatusLabel.uploadingChanges);
    await _flushOutbox(client);

    final appSettings = await _appSettingsStore.load();
    final entriesLimit = appSettings.remoteEntriesLimit;

    status?.update(label: SyncStatusLabel.syncingSubscriptions);
    final sub = await _syncSubscriptions(client, appSettings, status: status);

    if (entriesLimit < 0) return;

    status?.update(
      label: SyncStatusLabel.syncingUnreadArticles,
      current: 0,
      total: null,
    );
    await _syncItems(
      client,
      appSettings,
      remoteFeedIdToLocalFeed: sub.remoteFeedIdToLocalFeed,
      localFeedIdToFeed: sub.localFeedIdToFeed,
      localFeedIdToSettings: sub.localFeedIdToSettings,
      entriesLimit: entriesLimit,
      status: status,
      notify: notify,
    );
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
          'Fever outbox flush failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _outboxFailureContext(e, operation: 'flushOutboxSafe'),
        );
        return false;
      }
    });
  }

  Future<FeverClient> _buildClient() async {
    return _clientFactory.fever(account);
  }

  Future<
    ({
      Map<int, Feed> remoteFeedIdToLocalFeed,
      Map<int, Feed> localFeedIdToFeed,
      Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    })
  >
  _syncSubscriptions(
    FeverClient client,
    AppSettings appSettings, {
    SyncStatusTask? status,
  }) async {
    final remoteGroups = await client.getGroups();
    final remoteGroupIdToLocalId = <int, int>{};

    for (final g in remoteGroups) {
      final id = _asInt(g['id']);
      final title = g['title'];
      if (id == null || title is! String) continue;
      final localId = await _categories.upsertByName(title);
      remoteGroupIdToLocalId[id] = localId;
    }

    final remoteFeedIdToLocalCategoryId = <int, int>{};
    try {
      final mappings = await client.getFeedsGroups();
      for (final m in mappings) {
        final groupId = _asInt(m['group_id']);
        final feedIds = m['feed_ids'];
        if (groupId == null || feedIds is! String) continue;
        final localCatId = remoteGroupIdToLocalId[groupId];
        if (localCatId == null) continue;
        final ids = feedIds
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        for (final remoteFeedId in ids) {
          remoteFeedIdToLocalCategoryId.putIfAbsent(
            remoteFeedId,
            () => localCatId,
          );
        }
      }
    } catch (e) {
      AppLogger.w('Fever feeds_groups fetch failed', tag: 'sync', error: e);
    }

    final remoteFeeds = await client.getFeeds();
    status?.update(
      label: SyncStatusLabel.syncingSubscriptions,
      current: 0,
      total: remoteFeeds.length,
    );

    final remoteFeedIdToLocalFeed = <int, Feed>{};
    final localFeedIdToFeed = <int, Feed>{};
    final localFeedIdToSettings = <int, EffectiveFeedSettings>{};

    var processed = 0;
    for (final f in remoteFeeds) {
      processed += 1;
      status?.update(current: processed, total: remoteFeeds.length);

      final id = _asInt(f['id']);
      final feedUrl = f['url'];
      if (id == null || feedUrl is! String) continue;

      final localId = await _feeds.upsertUrl(feedUrl);
      final localCatId = remoteFeedIdToLocalCategoryId[id];
      if (localCatId != null) {
        await _feeds.setCategory(feedId: localId, categoryId: localCatId);
      }
      final local = await _feeds.getById(localId);
      if (local == null) continue;

      final title = f['title'] as String?;
      final siteUrl = f['site_url'] as String?;

      await _feeds.updateMeta(
        id: local.id,
        title: title,
        siteUrl: siteUrl,
        description: null,
        lastSyncedAt: DateTime.now(),
      );

      final refreshed = await _feeds.getById(localId);
      if (refreshed == null) continue;
      remoteFeedIdToLocalFeed[id] = refreshed;
      localFeedIdToFeed[refreshed.id] = refreshed;
    }

    // Resolve effective settings after categories are applied.
    for (final feed in localFeedIdToFeed.values) {
      final categoryId = feed.categoryId;
      final Category? category = categoryId == null
          ? null
          : await _categories.getById(categoryId);
      localFeedIdToSettings[feed.id] = EffectiveFeedSettings.resolve(
        feed,
        category,
        appSettings,
      );
    }

    // Update lastSyncedAt based on syncEnabled.
    for (final entry in localFeedIdToSettings.entries) {
      if (!entry.value.syncEnabled) {
        await _feeds.updateMeta(id: entry.key, lastSyncedAt: null);
      }
    }

    return (
      remoteFeedIdToLocalFeed: remoteFeedIdToLocalFeed,
      localFeedIdToFeed: localFeedIdToFeed,
      localFeedIdToSettings: localFeedIdToSettings,
    );
  }

  Future<void> _syncItems(
    FeverClient client,
    AppSettings appSettings, {
    required Map<int, Feed> remoteFeedIdToLocalFeed,
    required Map<int, Feed> localFeedIdToFeed,
    required Map<int, EffectiveFeedSettings> localFeedIdToSettings,
    required int entriesLimit,
    SyncStatusTask? status,
    required bool notify,
  }) async {
    final unreadIds = await client.getUnreadItemIds();
    final savedIds = await client.getSavedItemIds();

    final unreadSet = unreadIds.toSet();
    final savedSet = savedIds.toSet();

    final allIds = <int>{...unreadSet, ...savedSet}.toList();
    allIds.sort((a, b) => b.compareTo(a));

    final effectiveLimit = entriesLimit == 0 ? allIds.length : entriesLimit;
    final limitedIds = allIds.length > effectiveLimit
        ? allIds.sublist(0, effectiveLimit)
        : allIds;

    var totalNew = 0;
    var processed = 0;
    var webPagesRemaining = _maxWebPagesPerSync;

    for (var i = 0; i < limitedIds.length; i += 50) {
      final end = i + 50 > limitedIds.length ? limitedIds.length : i + 50;
      final batchIds = limitedIds.sublist(i, end);

      final items = await client.getItemsWithIds(batchIds);
      final byLocalFeedId = <int, List<Article>>{};

      for (final it in items) {
        final id = _asInt(it['id']);
        final remoteFeedId = _asInt(it['feed_id']);
        final url = it['url'];
        if (id == null || remoteFeedId == null || url is! String) continue;

        final localFeed = remoteFeedIdToLocalFeed[remoteFeedId];
        if (localFeed == null) continue;

        final settings = localFeedIdToSettings[localFeed.id];
        if (settings != null && !settings.syncEnabled) continue;
        if (settings != null &&
            settings.filterEnabled &&
            settings.filterKeywords.trim().isNotEmpty) {
          final ok = ReservedKeywordFilter.matches(
            pattern: settings.filterKeywords,
            fields: [
              it['title'] as String?,
              it['author'] as String?,
              url,
              it['html'] as String?,
            ],
          );
          if (!ok) continue;
        }

        final createdSeconds = _asInt(it['created_on_time']);
        final publishedAt = createdSeconds == null
            ? DateTime.now().toUtc()
            : DateTime.fromMillisecondsSinceEpoch(
                createdSeconds * 1000,
                isUtc: true,
              );

        final article = Article()
          ..remoteId = id.toString()
          ..link = url
          ..title = it['title'] as String?
          ..author = it['author'] as String?
          ..contentHtml = it['html'] as String?
          ..publishedAt = publishedAt
          ..isRead = !unreadSet.contains(id)
          ..isStarred = savedSet.contains(id);

        (byLocalFeedId[localFeed.id] ??= <Article>[]).add(article);
      }

      for (final entry in byLocalFeedId.entries) {
        final newArticles = await _articles.upsertMany(
          entry.key,
          entry.value,
          preserveUserState: false,
        );
        totalNew += newArticles.length;
        final settings = localFeedIdToSettings[entry.key];
        if (settings != null) {
          webPagesRemaining -= await _prefetchNewArticles(
            newArticles,
            settings,
            appSettings,
            remainingWebPageFetches: webPagesRemaining,
          );
        }
      }

      processed += batchIds.length;
      status?.update(current: processed, total: limitedIds.length);

      // Keep the isolate responsive for long queues.
      if (limitedIds.length > 200 && processed % 200 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (notify && totalNew > 0) {
      try {
        await _notifications.showNewArticlesSummaryNotification(
          totalNew,
          localeTag: appSettings.localeTag,
        );
      } catch (e) {
        AppLogger.w('Fever summary notification failed', tag: 'sync', error: e);
      }
    }
  }

  Future<int> _prefetchNewArticles(
    List<Article> newArticles,
    EffectiveFeedSettings settings,
    AppSettings appSettings, {
    required int remainingWebPageFetches,
  }) async {
    if (newArticles.isEmpty) return 0;

    if (settings.syncImages) {
      try {
        await _cache.cacheArticles(newArticles);
      } catch (_) {}
    }

    var attemptedWebPageFetches = 0;
    if (settings.syncWebPages && remainingWebPageFetches > 0) {
      final targets = newArticles.length <= remainingWebPageFetches
          ? newArticles
          : newArticles.sublist(0, remainingWebPageFetches);
      attemptedWebPageFetches = targets.length;
      try {
        await _syncWebPagesForArticles(
          targets,
          webUserAgent: appSettings.webUserAgent,
          syncImages: settings.syncImages,
        );
      } catch (_) {}
    }
    return attemptedWebPageFetches;
  }

  static const int _maxWebPagesPerSync = 8;

  Future<void> _syncWebPagesForArticles(
    List<Article> articles, {
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
            if ((a.extractedContentHtml ?? '').trim().isNotEmpty) return;

            final extracted = await _extractor.extract(
              a.link,
              userAgent: webUserAgent,
            );
            final html = extracted.contentHtml;
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

  Future<void> _flushOutbox(FeverClient client) async {
    final pending = await _outbox.load(account.id);
    if (pending.isEmpty) return;

    final executor = FeverRemoteArticleActionExecutor(client);
    final remaining = <OutboxAction>[];
    for (final a in pending) {
      try {
        await executor.apply(a);
      } catch (e, s) {
        AppLogger.w(
          'Fever outbox action failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _outboxFailureContext(
            e,
            operation: 'flushOutbox',
            action: a,
          ),
        );
        // Keep it for next sync attempt.
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
      'accountType': account.type.wire,
      'backend': 'fever',
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
}
