import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';

class FeedRepository {
  FeedRepository(this._isar);

  final Isar _isar;

  Stream<List<Feed>> watchAll() {
    return _isar.feeds.where().watch(fireImmediately: true);
  }

  Future<List<Feed>> getAll() {
    return _isar.feeds.where().findAll();
  }

  Future<Feed?> getById(int id) {
    return _isar.feeds.get(id);
  }

  Future<int> upsertUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Feed url is empty');
    }

    final existing = await _isar.feeds.filter().urlEqualTo(normalized).findFirst();
    final now = DateTime.now();
    final feed = existing ?? Feed()..url = normalized;
    feed.updatedAt = now;
    if (existing == null) {
      feed.createdAt = now;
    }

    return _isar.writeTxn(() async => _isar.feeds.put(feed));
  }

  Future<void> setCategory({required int feedId, int? categoryId}) async {
    // Step 1: Update Feed first (UI optimistic update will reflect immediately)
    await _isar.writeTxn(() async {
      final feed = await _isar.feeds.get(feedId);
      if (feed == null) return;
      feed.categoryId = categoryId;
      feed.updatedAt = DateTime.now();
      await _isar.feeds.put(feed);
    });

    // Step 2: Batch update Articles (async background, user won't notice)
    // [BUGFIX] Use batched processing to prevent OOM on feeds with many articles
    const batchSize = 200;

    // Only fetch IDs, not full objects (50000 ints = ~200KB vs 50000 objects = 100+ MB)
    final ids = await _isar.articles
        .filter()
        .feedIdEqualTo(feedId)
        .idProperty()
        .findAll();

    if (ids.isEmpty) return;

    final now = DateTime.now();
    for (var i = 0; i < ids.length; i += batchSize) {
      await _isar.writeTxn(() async {
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
      });
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

  Future<void> delete(int id) {
    return _isar.writeTxn(() async {
      await _isar.articles.filter().feedIdEqualTo(id).deleteAll();
      await _isar.feeds.delete(id);
    });
  }
}
