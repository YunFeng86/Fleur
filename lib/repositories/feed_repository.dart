import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';
import '../services/logging/app_logger.dart';
import 'remote_mirror_upsert_result.dart';

class FeedRepository {
  FeedRepository(this._isar);

  final Isar _isar;

  static String _normalizeRemoteId(String remoteId) => remoteId.trim();

  static String _normalizeUrlIdentity(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static bool _remoteIdCanBeBound(Feed feed, String remoteId) {
    final existing = feed.remoteId?.trim();
    return existing == null || existing.isEmpty || existing == remoteId;
  }

  static bool _urlIdentityMatches(Feed feed, String url) {
    return _normalizeUrlIdentity(feed.url) == _normalizeUrlIdentity(url);
  }

  Stream<List<Feed>> watchAll() {
    return _isar.feeds.where().watch(fireImmediately: true);
  }

  Future<List<Feed>> getAll() {
    return _isar.feeds.where().findAll();
  }

  Future<Feed?> getById(int id) {
    return _isar.feeds.get(id);
  }

  Future<Feed?> getByUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return Future.value(null);
    return _isar.feeds.filter().urlEqualTo(normalized).findFirst();
  }

  Future<Feed?> getByRemoteId(String remoteId) {
    final normalized = _normalizeRemoteId(remoteId);
    if (normalized.isEmpty) return Future.value(null);
    return _isar.feeds.filter().remoteIdEqualTo(normalized).findFirst();
  }

  Stream<Feed?> watchById(int id) {
    return _isar.feeds.watchObject(id, fireImmediately: true);
  }

  Future<int> upsertUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Feed url is empty');
    }

    final existing = await _isar.feeds
        .filter()
        .urlEqualTo(normalized)
        .findFirst();
    final now = DateTime.now();
    final feed = existing ?? Feed()
      ..url = normalized;
    feed.updatedAt = now;
    if (existing == null) {
      feed.createdAt = now;
    }

    return _isar.writeTxn(() async => _isar.feeds.put(feed));
  }

  Future<int> upsertRemote({
    required String remoteId,
    required String url,
    String? title,
    String? siteUrl,
    String? description,
    int? categoryId,
    DateTime? lastSyncedAt,
    int? preferredLocalFeedId,
    bool updateCategory = true,
  }) async {
    final result = await upsertRemoteDetailed(
      remoteId: remoteId,
      url: url,
      title: title,
      siteUrl: siteUrl,
      description: description,
      categoryId: categoryId,
      lastSyncedAt: lastSyncedAt,
      preferredLocalFeedId: preferredLocalFeedId,
      updateCategory: updateCategory,
    );
    return result.localId;
  }

  Future<RemoteMirrorUpsertResult> upsertRemoteDetailed({
    required String remoteId,
    required String url,
    String? title,
    String? siteUrl,
    String? description,
    int? categoryId,
    DateTime? lastSyncedAt,
    int? preferredLocalFeedId,
    bool updateCategory = true,
  }) async {
    final normalizedRemoteId = _normalizeRemoteId(remoteId);
    if (normalizedRemoteId.isEmpty) {
      throw ArgumentError('Feed remoteId is empty');
    }

    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('Feed url is empty');
    }

    final byRemoteId = await getByRemoteId(normalizedRemoteId);
    final preferred = byRemoteId == null && preferredLocalFeedId != null
        ? await _isar.feeds.get(preferredLocalFeedId)
        : null;
    final bindablePreferred =
        preferred != null &&
            _remoteIdCanBeBound(preferred, normalizedRemoteId) &&
            _urlIdentityMatches(preferred, normalizedUrl)
        ? preferred
        : null;
    final byUrl = await getByUrl(normalizedUrl);
    final bindableByUrl =
        byUrl != null && _remoteIdCanBeBound(byUrl, normalizedRemoteId)
        ? byUrl
        : null;
    final conflictingByUrl =
        byUrl != null && !_remoteIdCanBeBound(byUrl, normalizedRemoteId)
        ? byUrl
        : null;
    final byNormalizedUrl =
        byRemoteId == null && bindablePreferred == null && bindableByUrl == null
        ? await _getByNormalizedUrl(normalizedUrl)
        : null;
    final target =
        byRemoteId ?? bindablePreferred ?? bindableByUrl ?? byNormalizedUrl;
    final conflictingByNormalizedUrl = conflictingByUrl == null
        ? await _getConflictingByNormalizedUrl(
            normalizedUrl,
            normalizedRemoteId,
            excludeFeedId: target?.id,
          )
        : null;
    final conflict = conflictingByUrl ?? conflictingByNormalizedUrl;
    if (target == null && conflict != null) {
      AppLogger.w(
        'Skipped remote feed bind because url belongs to another remote feed',
        tag: 'sync',
        context: <String, Object?>{
          'remoteId': normalizedRemoteId,
          'url': normalizedUrl,
          'existingFeedId': conflict.id,
          'existingRemoteId': conflict.remoteId,
        },
      );
      return RemoteMirrorUpsertResult(
        localId: conflict.id,
        requestedRemoteId: normalizedRemoteId,
        effectiveRemoteId: conflict.remoteId?.trim(),
        status: RemoteMirrorUpsertStatus.identityConflict,
      );
    }
    final shouldPreserveTargetUrl =
        target != null && conflict != null && conflict.id != target.id;
    final duplicate = target == null
        ? null
        : await _findDuplicateForTarget(target, normalizedUrl);
    var duplicateDeleted = false;
    if (duplicate != null && await _canDeleteDuplicate(duplicate)) {
      await delete(duplicate.id);
      duplicateDeleted = true;
    } else if (duplicate != null) {
      AppLogger.w(
        'Preserved remote feed duplicate because it may contain local data',
        tag: 'sync',
        context: <String, Object?>{
          'remoteId': normalizedRemoteId,
          'url': normalizedUrl,
          'targetFeedId': target?.id,
          'duplicateFeedId': duplicate.id,
          'duplicateRemoteId': duplicate.remoteId,
        },
      );
    }
    final duplicateBlocksUrl = duplicate != null && !duplicateDeleted;
    final urlForWrite = (shouldPreserveTargetUrl || duplicateBlocksUrl)
        ? target!.url
        : normalizedUrl;

    return _isar.writeTxn(() async {
      final existing = target == null ? null : await _isar.feeds.get(target.id);
      final now = DateTime.now();
      final feed = existing ?? Feed()
        ..createdAt = now;
      feed
        ..remoteId = normalizedRemoteId
        ..url = urlForWrite
        ..title = title ?? feed.title
        ..siteUrl = siteUrl ?? feed.siteUrl
        ..description = description ?? feed.description
        ..updatedAt = now;
      if (updateCategory) {
        feed.categoryId = categoryId;
      }
      if (lastSyncedAt != null) {
        feed.lastSyncedAt = lastSyncedAt;
      }

      final id = await _isar.feeds.put(feed);
      if (updateCategory) {
        await _setArticleCategoryInTxn(id, categoryId, now);
      }
      return RemoteMirrorUpsertResult(
        localId: id,
        requestedRemoteId: normalizedRemoteId,
        effectiveRemoteId: normalizedRemoteId,
        status: RemoteMirrorUpsertStatus.bound,
      );
    });
  }

  Future<Feed?> _getByNormalizedUrl(String url) async {
    final normalized = _normalizeUrlIdentity(url);
    if (normalized.isEmpty) return null;
    final feeds = await getAll();
    for (final feed in feeds) {
      if (!_urlIdentityMatches(feed, normalized)) continue;
      final remoteId = feed.remoteId?.trim();
      if (remoteId != null && remoteId.isNotEmpty) continue;
      return feed;
    }
    return null;
  }

  Future<Feed?> _getConflictingByNormalizedUrl(
    String url,
    String remoteId, {
    int? excludeFeedId,
  }) async {
    final normalized = _normalizeUrlIdentity(url);
    if (normalized.isEmpty) return null;
    final feeds = await getAll();
    for (final feed in feeds) {
      if (feed.id == excludeFeedId) continue;
      if (!_urlIdentityMatches(feed, normalized)) continue;
      if (_remoteIdCanBeBound(feed, remoteId)) continue;
      return feed;
    }
    return null;
  }

  Future<Feed?> _findDuplicateForTarget(Feed target, String url) async {
    final normalized = _normalizeUrlIdentity(url);
    final feeds = await getAll();
    for (final feed in feeds) {
      if (feed.id == target.id) continue;
      if (!_urlIdentityMatches(feed, normalized)) continue;
      final remoteId = feed.remoteId?.trim();
      final targetRemoteId = target.remoteId?.trim();
      if (remoteId != null &&
          remoteId.isNotEmpty &&
          remoteId != targetRemoteId) {
        continue;
      }
      return feed;
    }
    return null;
  }

  Future<bool> _canDeleteDuplicate(Feed feed) async {
    final remoteId = feed.remoteId?.trim();
    if (remoteId != null && remoteId.isNotEmpty) return false;
    final article = await _isar.articles
        .filter()
        .feedIdEqualTo(feed.id)
        .findFirst();
    return article == null;
  }

  Future<void> deleteRemoteMissing(
    Set<String> seenRemoteIds, {
    bool allowEmptyPrune = false,
    Set<String> protectedRemoteIds = const {},
  }) async {
    final seen = seenRemoteIds
        .map(_normalizeRemoteId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final protected = protectedRemoteIds
        .map(_normalizeRemoteId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final remoteFeeds = await _isar.feeds
        .filter()
        .remoteIdIsNotNull()
        .findAll();
    if (seen.isEmpty && remoteFeeds.isNotEmpty && !allowEmptyPrune) {
      AppLogger.w(
        'Skipped remote feed prune because remote id list is empty',
        tag: 'sync',
        context: <String, Object?>{'remoteFeedCount': remoteFeeds.length},
      );
      return;
    }
    final deleteIds = <int>[];
    for (final feed in remoteFeeds) {
      final remoteId = feed.remoteId?.trim();
      if (remoteId == null || remoteId.isEmpty) continue;
      if (protected.contains(remoteId)) continue;
      if (!seen.contains(remoteId)) deleteIds.add(feed.id);
    }
    if (deleteIds.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final id in deleteIds) {
        await _deleteInTxn(id);
      }
    });
  }

  Future<void> setCategory({required int feedId, int? categoryId}) async {
    // Single transaction to prevent race conditions
    // This ensures Feed and Articles are updated atomically
    await _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(feedId);
      if (feed == null) return;

      feed.categoryId = categoryId;
      final now = DateTime.now();
      feed.updatedAt = now;
      await _isar.feeds.put(feed);
      await _setArticleCategoryInTxn(feedId, categoryId, now);
    });
  }

  Future<void> _setArticleCategoryInTxn(
    int feedId,
    int? categoryId,
    DateTime now,
  ) async {
    // Batch update Articles to prevent OOM on feeds with many articles
    // Only fetch IDs first (50000 ints = ~200KB vs 50000 objects = 100+ MB)
    final ids = await _isar.articles
        .filter()
        .feedIdEqualTo(feedId)
        .idProperty()
        .findAll();

    if (ids.isEmpty) return;

    const batchSize = 200;

    for (var i = 0; i < ids.length; i += batchSize) {
      final end = (i + batchSize > ids.length) ? ids.length : i + batchSize;
      final batchIds = ids.sublist(i, end);

      // Load full objects in batches
      final items = await _isar.articles.getAll(batchIds);
      final updates = <Article>[];
      for (final a in items) {
        if (a == null) continue;
        a.categoryId = categoryId;
        a.updatedAt = now;
        updates.add(a);
      }
      if (updates.isNotEmpty) {
        await _isar.articles.putAll(updates);
      }
    }
  }

  Future<void> setUserTitle({required int feedId, String? userTitle}) {
    return _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(feedId);
      if (feed == null) return;
      final t = userTitle?.trim();
      feed.userTitle = (t == null || t.isEmpty) ? null : t;
      feed.updatedAt = DateTime.now();
      await _isar.feeds.put(feed);
    });
  }

  Future<void> updateMeta({
    required int id,
    String? title,
    String? siteUrl,
    String? description,
    DateTime? lastSyncedAt,
  }) {
    return _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(id);
      if (feed == null) return;
      feed.title = title ?? feed.title;
      feed.siteUrl = siteUrl ?? feed.siteUrl;
      feed.description = description ?? feed.description;
      feed.lastSyncedAt = lastSyncedAt ?? feed.lastSyncedAt;
      feed.updatedAt = DateTime.now();
      await _isar.feeds.put(feed);
    });
  }

  Future<void> updateSyncState({
    required int id,
    DateTime? lastCheckedAt,
    int? lastStatusCode,
    int? lastDurationMs,
    int? lastIncomingCount,
    String? etag,
    String? lastModified,
    String? lastError,
    DateTime? lastErrorAt,
    required bool clearError,
  }) {
    return _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(id);
      if (feed == null) return;

      feed.lastCheckedAt = lastCheckedAt ?? feed.lastCheckedAt;
      feed.lastStatusCode = lastStatusCode ?? feed.lastStatusCode;
      feed.lastDurationMs = lastDurationMs ?? feed.lastDurationMs;
      feed.lastIncomingCount = lastIncomingCount ?? feed.lastIncomingCount;
      feed.etag = etag ?? feed.etag;
      feed.lastModified = lastModified ?? feed.lastModified;

      if (clearError) {
        feed.lastError = null;
        feed.lastErrorAt = null;
      } else {
        feed.lastError = lastError ?? feed.lastError;
        feed.lastErrorAt = lastErrorAt ?? feed.lastErrorAt;
      }

      feed.updatedAt = DateTime.now();
      await _isar.feeds.put(feed);
    });
  }

  Future<void> updateSettings({
    required int id,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) {
    return _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(id);
      if (feed == null) return;

      if (updateFilterEnabled) feed.filterEnabled = filterEnabled;
      if (updateFilterKeywords) feed.filterKeywords = filterKeywords;
      if (updateSyncEnabled) feed.syncEnabled = syncEnabled;
      if (updateSyncImages) feed.syncImages = syncImages;
      if (updateSyncWebPages) feed.syncWebPages = syncWebPages;
      if (updateShowAiSummary) feed.showAiSummary = showAiSummary;
      if (updateAutoTranslate) feed.autoTranslate = autoTranslate;

      feed.updatedAt = DateTime.now();
      await _isar.feeds.put(feed);
    });
  }

  Future<void> delete(int id) {
    return _isar.writeTxn(() async {
      await _deleteInTxn(id);
    });
  }

  Future<void> _deleteInTxn(int id) async {
    await _isar.articles.filter().feedIdEqualTo(id).deleteAll();
    await _isar.feeds.delete(id);
  }
}
