import 'package:dio/dio.dart';

import '../../../models/article.dart';
import '../../../models/feed.dart';
import '../../../repositories/article_repository.dart';
import '../../../repositories/category_repository.dart';
import '../../../repositories/feed_repository.dart';
import '../../../utils/keyword_filter.dart';
import '../../accounts/account.dart';
import '../../accounts/credential_store.dart';
import '../../cache/article_cache_service.dart';
import '../../logging/app_logger.dart';
import '../../logging/log_context.dart';
import '../../settings/app_settings.dart';
import '../../settings/app_settings_store.dart';
import '../effective_feed_settings.dart';
import '../outbox/outbox_delivery.dart';
import '../outbox/outbox_store.dart';
import '../remote_article_action_executor.dart';
import '../remote_client_factory.dart';
import '../sync_mutex.dart';
import '../sync_service.dart';
import '../sync_status_reporter.dart';
import 'google_reader_client.dart';
import 'google_reader_provider_profile.dart';

class _GoogleReaderEntryCounts {
  const _GoogleReaderEntryCounts({
    required this.incomingCount,
    required this.newCount,
  });

  static const zero = _GoogleReaderEntryCounts(incomingCount: 0, newCount: 0);

  final int incomingCount;
  final int newCount;

  _GoogleReaderEntryCounts plus(_GoogleReaderEntryCounts other) {
    return _GoogleReaderEntryCounts(
      incomingCount: incomingCount + other.incomingCount,
      newCount: newCount + other.newCount,
    );
  }
}

class _GoogleReaderEntrySyncResult {
  const _GoogleReaderEntrySyncResult({
    required this.incomingCount,
    required this.newCount,
    required this.byFeedId,
  });

  static const zero = _GoogleReaderEntrySyncResult(
    incomingCount: 0,
    newCount: 0,
    byFeedId: <int, _GoogleReaderEntryCounts>{},
  );

  final int incomingCount;
  final int newCount;
  final Map<int, _GoogleReaderEntryCounts> byFeedId;

  _GoogleReaderEntrySyncResult plus(_GoogleReaderEntrySyncResult other) {
    if (other.incomingCount == 0 && other.newCount == 0) return this;
    if (incomingCount == 0 && newCount == 0 && byFeedId.isEmpty) return other;

    final merged = <int, _GoogleReaderEntryCounts>{...byFeedId};
    for (final entry in other.byFeedId.entries) {
      merged[entry.key] = (merged[entry.key] ?? _GoogleReaderEntryCounts.zero)
          .plus(entry.value);
    }
    return _GoogleReaderEntrySyncResult(
      incomingCount: incomingCount + other.incomingCount,
      newCount: newCount + other.newCount,
      byFeedId: merged,
    );
  }
}

class _GoogleReaderRemoteIdSet {
  const _GoogleReaderRemoteIdSet({required this.ids, required this.complete});

  final Set<String> ids;
  final bool complete;
}

class _GoogleReaderFeedIndex {
  _GoogleReaderFeedIndex({
    required this.byLocalId,
    required this.byRemoteStreamId,
    required this.byFeedUrl,
    required this.settingsByLocalId,
  });

  final Map<int, Feed> byLocalId;
  final Map<String, Feed> byRemoteStreamId;
  final Map<String, Feed> byFeedUrl;
  final Map<int, EffectiveFeedSettings> settingsByLocalId;

  Feed? feedForItem(Map<String, Object?> item) {
    final origin = item['origin'];
    if (origin is Map) {
      final map = origin.cast<String, Object?>();
      final streamId = GoogleReaderSyncService._stringValue(map['streamId']);
      final byStream = streamId == null ? null : byRemoteStreamId[streamId];
      if (byStream != null) return byStream;

      final feedUrl = GoogleReaderSyncService._feedUrlFromStreamId(streamId);
      final byUrl = feedUrl == null ? null : byFeedUrl[_normalizeUrl(feedUrl)];
      if (byUrl != null) return byUrl;
    }

    final streamId = GoogleReaderSyncService._stringValue(item['streamId']);
    final byStream = streamId == null ? null : byRemoteStreamId[streamId];
    if (byStream != null) return byStream;

    final feedUrl = GoogleReaderSyncService._feedUrlFromStreamId(streamId);
    return feedUrl == null ? null : byFeedUrl[_normalizeUrl(feedUrl)];
  }

  static String _normalizeUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }
}

class GoogleReaderSyncService implements SyncServiceBase, OutboxFlushCapable {
  GoogleReaderSyncService({
    required this.account,
    required Dio dio,
    required CredentialStore credentials,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required ArticleRepository articles,
    required OutboxStore outbox,
    required AppSettingsStore appSettingsStore,
    required ArticleCacheService cache,
    SyncStatusReporter? statusReporter,
  }) : _clientFactory = RemoteClientFactory(dio: dio, credentials: credentials),
       _profile = GoogleReaderProviderProfiles.forAccount(account),
       _feeds = feeds,
       _categories = categories,
       _articles = articles,
       _outbox = outbox,
       _appSettingsStore = appSettingsStore,
       _cache = cache,
       _statusReporter = statusReporter ?? const NoopSyncStatusReporter();

  final Account account;

  final RemoteClientFactory _clientFactory;
  final GoogleReaderProviderProfile _profile;
  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final ArticleRepository _articles;
  final OutboxStore _outbox;
  final AppSettingsStore _appSettingsStore;
  final ArticleCacheService _cache;
  final SyncStatusReporter _statusReporter;

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
    final batch = await syncAccountSafe(feedIds: [feedId], notify: notify);
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
  }) {
    return syncAccountSafe(
      maxConcurrent: maxConcurrent,
      onProgress: onProgress,
      notify: notify,
      feedIds: feedIds,
    );
  }

  @override
  Future<BatchRefreshResult> syncAccountSafe({
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    Iterable<int>? feedIds,
  }) {
    return SyncMutex.instance.run('sync', () async {
      final ids = feedIds?.toList(growable: false) ?? const <int>[];
      final status = _statusReporter.startTask(
        label: SyncStatusLabel.syncing,
        detail: account.name.trim().isEmpty ? null : account.name.trim(),
      );
      try {
        final results = await syncNow(status: status, feedIds: ids);
        onProgress?.call(ids.length, ids.length);
        status.complete(success: true);
        return BatchRefreshResult(results);
      } catch (e, s) {
        onProgress?.call(ids.length, ids.length);
        status.complete(success: false);
        AppLogger.w(
          'Google Reader account sync failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _accountFailureContext(e, operation: 'refreshAccount'),
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

  Future<List<FeedRefreshResult>> syncNow({
    SyncStatusTask? status,
    Iterable<int>? feedIds,
  }) async {
    final client = await _clientFactory.googleReader(account);
    status?.update(label: SyncStatusLabel.uploadingChanges);
    await _flushOutbox(client);

    final appSettings = await _appSettingsStore.load();

    status?.update(label: SyncStatusLabel.syncingSubscriptions);
    final feedIndex = await _syncSubscriptions(
      client,
      appSettings: appSettings,
      status: status,
    );

    final ids = feedIds?.toList(growable: false) ?? const <int>[];
    final entriesLimit = appSettings.remoteEntriesLimit;
    if (entriesLimit < 0) {
      return _refreshResults(ids, _GoogleReaderEntrySyncResult.zero);
    }

    final result = ids.isEmpty
        ? await _syncReadingListEntries(
            client,
            appSettings,
            feedIndex: feedIndex,
            status: status,
          )
        : await _syncFeedEntries(
            client,
            appSettings,
            feedIndex: feedIndex,
            feedIds: ids,
            status: status,
          );
    if (ids.isEmpty) {
      await _reconcileAccountState(client, appSettings);
    } else {
      await _reconcileFeedReadStates(
        client,
        appSettings,
        feedIndex: feedIndex,
        feedIds: ids,
      );
    }
    return _refreshResults(ids, result);
  }

  @override
  Future<bool> flushOutboxSafe() async {
    return SyncMutex.instance.run('sync', () async {
      try {
        final client = await _clientFactory.googleReader(account);
        await _flushOutbox(client);
        return true;
      } catch (e, s) {
        AppLogger.w(
          'Google Reader outbox flush failed',
          tag: 'sync',
          error: e,
          stackTrace: s,
          context: _accountFailureContext(e, operation: 'flushOutboxSafe'),
        );
        return false;
      }
    });
  }

  Future<_GoogleReaderFeedIndex> _syncSubscriptions(
    GoogleReaderClient client, {
    required AppSettings appSettings,
    SyncStatusTask? status,
  }) async {
    final subscriptions = await client.subscriptionList();
    status?.update(
      label: SyncStatusLabel.syncingSubscriptions,
      current: 0,
      total: subscriptions.length,
    );

    final seenFeedRemoteIds = <String>{};
    final seenCategoryRemoteIds = <String>{};
    final protectedFeedRemoteIds = <String>{};
    final feedMirrorIndex = await _feeds.createRemoteMirrorIndex();
    final byLocalId = <int, Feed>{};
    final byRemoteStreamId = <String, Feed>{};
    final byFeedUrl = <String, Feed>{};
    final settingsByLocalId = <int, EffectiveFeedSettings>{};
    var processed = 0;

    for (final subscription in subscriptions) {
      processed += 1;
      status?.update(current: processed, total: subscriptions.length);
      final remoteId = _stringValue(subscription['id']);
      final url = _feedUrlForSubscription(subscription);
      if (remoteId == null || url == null) continue;

      final category = await _primaryCategory(subscription);
      final result = await _feeds.upsertRemoteDetailed(
        remoteId: remoteId,
        url: url,
        title: _stringValue(subscription['title']),
        siteUrl: _stringValue(subscription['htmlUrl']),
        description: null,
        categoryId: category?.id,
        lastSyncedAt: DateTime.now(),
        updateCategory: category != null,
        lookupIndex: feedMirrorIndex,
      );
      if (result.isBound) {
        seenFeedRemoteIds.add(remoteId);
        if (category != null) {
          seenCategoryRemoteIds.add(category.remoteId);
        }
        final feed = await _feeds.getById(result.localId);
        if (feed != null) {
          final settings = await _resolveSettings(feed, appSettings);
          byLocalId[feed.id] = feed;
          byRemoteStreamId[remoteId] = feed;
          byFeedUrl[_GoogleReaderFeedIndex._normalizeUrl(url)] = feed;
          settingsByLocalId[feed.id] = settings;
        }
      } else {
        final protectedId = result.effectiveRemoteId;
        if (protectedId != null && protectedId.isNotEmpty) {
          protectedFeedRemoteIds.add(protectedId);
        }
      }
    }

    final allowFeedProtectedOnlyPrune =
        subscriptions.isNotEmpty &&
        seenFeedRemoteIds.isEmpty &&
        protectedFeedRemoteIds.isNotEmpty;
    await _feeds.deleteRemoteMissing(
      seenFeedRemoteIds,
      allowEmptyPrune: allowFeedProtectedOnlyPrune,
      protectedRemoteIds: protectedFeedRemoteIds,
    );
    await _categories.deleteRemoteMissing(seenCategoryRemoteIds);

    return _GoogleReaderFeedIndex(
      byLocalId: byLocalId,
      byRemoteStreamId: byRemoteStreamId,
      byFeedUrl: byFeedUrl,
      settingsByLocalId: settingsByLocalId,
    );
  }

  Future<({int id, String remoteId})?> _primaryCategory(
    Map<String, Object?> subscription,
  ) async {
    final rawCategories = subscription['categories'];
    if (rawCategories is! List || rawCategories.isEmpty) return null;
    for (final raw in rawCategories) {
      if (raw is! Map) continue;
      final category = raw.cast<String, Object?>();
      final remoteId = _stringValue(category['id']);
      final label = _stringValue(category['label']) ?? remoteId;
      if (remoteId == null || label == null) continue;
      final result = await _categories.upsertRemoteDetailed(
        remoteId: remoteId,
        name: label,
      );
      if (result.isBound) {
        return (id: result.localId, remoteId: remoteId);
      }
    }
    return null;
  }

  Future<_GoogleReaderEntrySyncResult> _syncReadingListEntries(
    GoogleReaderClient client,
    AppSettings appSettings, {
    required _GoogleReaderFeedIndex feedIndex,
    SyncStatusTask? status,
  }) {
    return _syncStreamEntries(
      client,
      appSettings,
      feedIndex: feedIndex,
      streamId: GoogleReaderRemoteArticleActionExecutor.readingListState,
      status: status,
    );
  }

  Future<_GoogleReaderEntrySyncResult> _syncFeedEntries(
    GoogleReaderClient client,
    AppSettings appSettings, {
    required _GoogleReaderFeedIndex feedIndex,
    required List<int> feedIds,
    SyncStatusTask? status,
  }) async {
    var result = _GoogleReaderEntrySyncResult.zero;
    for (final feedId in feedIds) {
      final feed = feedIndex.byLocalId[feedId] ?? await _feeds.getById(feedId);
      if (feed == null) continue;
      final settings =
          feedIndex.settingsByLocalId[feed.id] ??
          await _resolveSettings(feed, appSettings);
      if (!settings.syncEnabled) continue;
      result = result.plus(
        await _syncStreamEntries(
          client,
          appSettings,
          feedIndex: feedIndex,
          streamId: _streamIdForFeed(feed),
          expectedLocalFeedId: feed.id,
          status: status,
        ),
      );
    }
    return result;
  }

  Future<_GoogleReaderEntrySyncResult> _syncStreamEntries(
    GoogleReaderClient client,
    AppSettings appSettings, {
    required _GoogleReaderFeedIndex feedIndex,
    required String streamId,
    int? expectedLocalFeedId,
    SyncStatusTask? status,
  }) async {
    final entriesLimit = appSettings.remoteEntriesLimit;
    if (entriesLimit < 0) return _GoogleReaderEntrySyncResult.zero;

    status?.update(
      label: SyncStatusLabel.syncingUnreadArticles,
      current: 0,
      total: entriesLimit == 0 ? null : entriesLimit,
    );

    String? continuation;
    var fetchedIds = 0;
    var result = _GoogleReaderEntrySyncResult.zero;
    while (entriesLimit == 0 || fetchedIds < entriesLimit) {
      final remaining = entriesLimit == 0
          ? _profile.itemIdsPageSize
          : entriesLimit - fetchedIds;
      final count = remaining < _profile.itemIdsPageSize
          ? remaining
          : _profile.itemIdsPageSize;
      if (count <= 0) break;

      final page = await client.streamItemIds(
        streamId: streamId,
        count: count,
        continuation: continuation,
      );
      if (page.itemIds.isEmpty) break;
      fetchedIds += page.itemIds.length;
      final pageItemIds = _dedupeIds(page.itemIds);

      status?.update(
        current: fetchedIds,
        total: entriesLimit == 0 ? fetchedIds : entriesLimit,
      );

      for (var i = 0; i < pageItemIds.length; i += _profile.contentBatchSize) {
        final end = i + _profile.contentBatchSize > pageItemIds.length
            ? pageItemIds.length
            : i + _profile.contentBatchSize;
        final items = await client.streamItemsContents(
          pageItemIds.sublist(i, end),
        );
        result = result.plus(
          await _processItems(
            items,
            appSettings,
            feedIndex: feedIndex,
            expectedLocalFeedId: expectedLocalFeedId,
          ),
        );
      }

      continuation = page.continuation;
      if (continuation == null || continuation.isEmpty) break;
      await Future<void>.delayed(Duration.zero);
    }
    return result;
  }

  Future<void> _reconcileAccountState(
    GoogleReaderClient client,
    AppSettings appSettings,
  ) async {
    final unread = await _fetchRemoteIdSet(
      client,
      appSettings,
      streamId: GoogleReaderRemoteArticleActionExecutor.readingListState,
      excludeState: GoogleReaderRemoteArticleActionExecutor.readState,
    );
    await _articles.reconcileRemoteReadStates(
      unreadRemoteIds: unread.ids,
      complete: unread.complete,
    );

    final starred = await _fetchRemoteIdSet(
      client,
      appSettings,
      streamId: GoogleReaderRemoteArticleActionExecutor.starredState,
    );
    await _articles.reconcileRemoteStarredStates(
      starredRemoteIds: starred.ids,
      complete: starred.complete,
    );

    try {
      await client.unreadCounts();
    } catch (e, s) {
      AppLogger.w(
        'Google Reader unread-count diagnostics failed',
        tag: 'sync',
        error: e,
        stackTrace: s,
        context: _accountFailureContext(e, operation: 'unreadCountDiagnostics'),
      );
    }
  }

  Future<void> _reconcileFeedReadStates(
    GoogleReaderClient client,
    AppSettings appSettings, {
    required _GoogleReaderFeedIndex feedIndex,
    required List<int> feedIds,
  }) async {
    for (final feedId in feedIds) {
      final feed = feedIndex.byLocalId[feedId] ?? await _feeds.getById(feedId);
      if (feed == null) continue;
      final unread = await _fetchRemoteIdSet(
        client,
        appSettings,
        streamId: _streamIdForFeed(feed),
        excludeState: GoogleReaderRemoteArticleActionExecutor.readState,
      );
      await _articles.reconcileRemoteReadStates(
        unreadRemoteIds: unread.ids,
        complete: unread.complete,
        feedId: feed.id,
      );
    }
  }

  Future<_GoogleReaderRemoteIdSet> _fetchRemoteIdSet(
    GoogleReaderClient client,
    AppSettings appSettings, {
    required String streamId,
    String? excludeState,
    int? maxItems,
  }) async {
    final entriesLimit = maxItems ?? appSettings.remoteEntriesLimit;
    if (entriesLimit < 0) {
      return const _GoogleReaderRemoteIdSet(ids: <String>{}, complete: false);
    }
    final ids = <String>{};
    String? continuation;
    var fetched = 0;
    var complete = false;
    while (entriesLimit == 0 || fetched < entriesLimit) {
      final remaining = entriesLimit == 0
          ? _profile.itemIdsPageSize
          : entriesLimit - fetched;
      final count = remaining < _profile.itemIdsPageSize
          ? remaining
          : _profile.itemIdsPageSize;
      if (count <= 0) break;
      final page = await client.streamItemIds(
        streamId: streamId,
        count: count,
        continuation: continuation,
        excludeState: excludeState,
      );
      fetched += page.itemIds.length;
      ids.addAll(_dedupeIds(page.itemIds));
      continuation = page.continuation;
      if (continuation == null || continuation.isEmpty) {
        complete = true;
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return _GoogleReaderRemoteIdSet(ids: ids, complete: complete);
  }

  Future<_GoogleReaderEntrySyncResult> _processItems(
    List<Map<String, Object?>> items,
    AppSettings appSettings, {
    required _GoogleReaderFeedIndex feedIndex,
    int? expectedLocalFeedId,
  }) async {
    if (items.isEmpty) return _GoogleReaderEntrySyncResult.zero;

    final byLocalFeedId = <int, List<Article>>{};
    for (final item in items) {
      final localFeed = feedIndex.feedForItem(item);
      if (localFeed == null) continue;
      if (expectedLocalFeedId != null && localFeed.id != expectedLocalFeedId) {
        continue;
      }
      final settings =
          feedIndex.settingsByLocalId[localFeed.id] ??
          await _resolveSettings(localFeed, appSettings);
      if (!settings.syncEnabled) continue;

      final article = _articleFromItem(item);
      if (article == null) continue;
      if (!_matchesFilter(article, settings)) continue;
      byLocalFeedId.putIfAbsent(localFeed.id, () => <Article>[]).add(article);
    }

    if (byLocalFeedId.isEmpty) return _GoogleReaderEntrySyncResult.zero;

    var incomingCount = 0;
    var newCount = 0;
    final byFeedId = <int, _GoogleReaderEntryCounts>{};
    for (final entry in byLocalFeedId.entries) {
      incomingCount += entry.value.length;
      final newArticles = await _articles.upsertMany(
        entry.key,
        entry.value,
        preserveUserState: false,
      );
      newCount += newArticles.length;
      byFeedId[entry.key] = _GoogleReaderEntryCounts(
        incomingCount: entry.value.length,
        newCount: newArticles.length,
      );
      await _feeds.updateMeta(id: entry.key, lastSyncedAt: DateTime.now());
    }

    return _GoogleReaderEntrySyncResult(
      incomingCount: incomingCount,
      newCount: newCount,
      byFeedId: byFeedId,
    );
  }

  Future<EffectiveFeedSettings> _resolveSettings(
    Feed feed,
    AppSettings appSettings,
  ) async {
    final categoryId = feed.categoryId;
    final category = categoryId == null
        ? null
        : await _categories.getById(categoryId);
    return EffectiveFeedSettings.resolve(feed, category, appSettings);
  }

  List<FeedRefreshResult> _refreshResults(
    List<int> feedIds,
    _GoogleReaderEntrySyncResult result,
  ) {
    if (feedIds.isEmpty) {
      return [
        FeedRefreshResult(
          feedId: -1,
          incomingCount: result.incomingCount,
          newCount: result.newCount,
        ),
      ];
    }
    return [
      for (final feedId in feedIds)
        FeedRefreshResult(
          feedId: feedId,
          incomingCount: result.byFeedId[feedId]?.incomingCount ?? 0,
          newCount: result.byFeedId[feedId]?.newCount ?? 0,
        ),
    ];
  }

  Future<void> _flushOutbox(GoogleReaderClient client) async {
    final executor = GoogleReaderRemoteArticleActionExecutor(client);
    await OutboxDelivery(_outbox).flush(
      accountId: account.id,
      apply: executor.apply,
      onActionError: (action, error, stackTrace) {
        AppLogger.w(
          'Google Reader outbox action failed',
          tag: 'sync',
          error: error,
          stackTrace: stackTrace,
          context: _accountFailureContext(
            error,
            operation: 'flushOutbox',
            action: action,
          ),
        );
      },
      batching: OutboxBatching(
        maxSize: _profile.editTagBatchSize,
        isBatchable: GoogleReaderRemoteArticleActionExecutor.isBatchable,
        isCompatible: _isCompatibleOutboxBatchAction,
        apply: executor.applyBatch,
      ),
    );
  }

  static bool _isCompatibleOutboxBatchAction(
    OutboxAction first,
    OutboxAction next,
  ) {
    return GoogleReaderRemoteArticleActionExecutor.isBatchable(next) &&
        first.type == next.type &&
        first.value == next.value;
  }

  Map<String, Object?> _accountFailureContext(
    Object error, {
    required String operation,
    OutboxAction? action,
  }) {
    final extra = <String, Object?>{
      'accountId': account.id,
      'accountType': 'googleReader',
      'backend': 'googleReader',
      'operation': operation,
      'profileId': account.profileId,
      if (action != null) ...<String, Object?>{
        'actionType': action.type.wire,
        'remoteEntryKeyPresent': (action.remoteEntryKey ?? '').isNotEmpty,
        'streamIdPresent': (action.streamId ?? '').isNotEmpty,
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

  static Article? _articleFromItem(Map<String, Object?> item) {
    final itemId = _stringValue(item['id']);
    if (itemId == null) return null;

    final link = _articleLink(item) ?? itemId;
    final contentHtml =
        _contentValue(item['content']) ?? _contentValue(item['summary']);
    final categories = _stringList(item['categories']).toSet();
    final publishedAt =
        _parseEpochSeconds(item['published']) ??
        _parseEpochSeconds(item['updated']) ??
        _parseEpochMicros(item['timestampUsec']) ??
        _parseEpochMillis(item['crawlTimeMsec']) ??
        DateTime.now().toUtc();

    return Article()
      ..remoteId = itemId
      ..link = link
      ..title = _stringValue(item['title'])
      ..author = _stringValue(item['author'])
      ..contentHtml = contentHtml
      ..publishedAt = publishedAt
      ..isRead = _containsState(
        categories,
        GoogleReaderRemoteArticleActionExecutor.readState,
      )
      ..isStarred = _containsState(
        categories,
        GoogleReaderRemoteArticleActionExecutor.starredState,
      );
  }

  static bool _containsState(Set<String> categories, String stateId) {
    final expected = _normalizeStateId(stateId);
    return categories.any((value) => _normalizeStateId(value) == expected);
  }

  static String _normalizeStateId(String stateId) {
    final value = stateId.trim();
    const statePrefix = '/state/';
    final stateIndex = value.indexOf(statePrefix);
    if (!value.startsWith('user/') || stateIndex < 0) return value;
    return 'user/-${value.substring(stateIndex)}';
  }

  static bool _matchesFilter(Article article, EffectiveFeedSettings settings) {
    if (!settings.filterEnabled || settings.filterKeywords.trim().isEmpty) {
      return true;
    }
    return ReservedKeywordFilter.matches(
      pattern: settings.filterKeywords,
      fields: [
        article.title,
        article.author,
        article.link,
        article.contentHtml,
      ],
    );
  }

  static List<String> _dedupeIds(Iterable<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      result.add(id);
    }
    return result;
  }

  static String? _articleLink(Map<String, Object?> item) {
    for (final key in const ['alternate', 'canonical']) {
      final raw = item[key];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is! Map) continue;
          final href = _stringValue(entry.cast<String, Object?>()['href']);
          if (href != null) return href;
        }
      }
    }
    return _stringValue(item['href']) ?? _stringValue(item['url']);
  }

  static String? _contentValue(Object? raw) {
    if (raw is String) return _stringValue(raw);
    if (raw is! Map) return null;
    final map = raw.cast<String, Object?>();
    return _stringValue(map['content']) ?? _stringValue(map['html']);
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((value) => value?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _parseEpochSeconds(Object? value) {
    final seconds = _readInt(value);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static DateTime? _parseEpochMillis(Object? value) {
    final millis = _readInt(value);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static DateTime? _parseEpochMicros(Object? value) {
    final micros = _readInt(value);
    if (micros == null || micros <= 0) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _streamIdForFeed(Feed feed) {
    final remoteId = feed.remoteId?.trim();
    if (remoteId != null && remoteId.isNotEmpty) {
      if (remoteId.startsWith('feed/')) return remoteId;
      if (remoteId.startsWith('user/-/')) return remoteId;
    }
    return 'feed/${feed.url.trim()}';
  }

  static String? _feedUrlForSubscription(Map<String, Object?> subscription) {
    final url = _stringValue(subscription['url']);
    if (url != null && url.isNotEmpty) return url;
    return _feedUrlFromStreamId(_stringValue(subscription['id']));
  }

  static String? _feedUrlFromStreamId(String? streamId) {
    final value = streamId?.trim();
    if (value == null || value.isEmpty) return null;
    const prefix = 'feed/';
    if (!value.startsWith(prefix)) return null;
    final feedUrl = value.substring(prefix.length).trim();
    return feedUrl.isEmpty ? null : feedUrl;
  }

  static String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
