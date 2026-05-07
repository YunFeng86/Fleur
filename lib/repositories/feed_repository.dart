import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';

class FeedRepository {
  FeedRepository(this._isar);

  final Isar _isar;

  static String _normalizeRemoteId(String remoteId) => remoteId.trim();

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
    final byUrl = await getByUrl(normalizedUrl);
    if (byRemoteId != null && byUrl != null && byUrl.id != byRemoteId.id) {
      await delete(byUrl.id);
    }

    return _isar.writeTxn(() async {
      final existing = byRemoteId == null
          ? await _isar.feeds.filter().urlEqualTo(normalizedUrl).findFirst()
          : await _isar.feeds.get(byRemoteId.id);
      final now = DateTime.now();
      final feed = existing ?? Feed()
        ..createdAt = now;
      feed
        ..remoteId = normalizedRemoteId
        ..url = normalizedUrl
        ..title = title ?? feed.title
        ..siteUrl = siteUrl ?? feed.siteUrl
        ..description = description ?? feed.description
        ..categoryId = categoryId
        ..updatedAt = now;
      if (lastSyncedAt != null) {
        feed.lastSyncedAt = lastSyncedAt;
      }

      final id = await _isar.feeds.put(feed);
      await _setArticleCategoryInTxn(id, categoryId, now);
      return id;
    });
  }

  Future<void> deleteRemoteMissing(Set<String> seenRemoteIds) async {
    final seen = seenRemoteIds
        .map(_normalizeRemoteId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final remoteFeeds = await _isar.feeds
        .filter()
        .remoteIdIsNotNull()
        .findAll();
    final deleteIds = <int>[];
    for (final feed in remoteFeeds) {
      final remoteId = feed.remoteId?.trim();
      if (remoteId == null || remoteId.isEmpty) continue;
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
