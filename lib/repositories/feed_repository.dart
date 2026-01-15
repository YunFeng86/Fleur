import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/feed.dart';

class FeedRepository {
  FeedRepository(this._isar);

  final Isar _isar;

  Stream<List<Feed>> watchAll() {
    return _isar.feeds.where().watch(fireImmediately: true);
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

  Future<void> delete(int id) {
    return _isar.writeTxn(() async {
      await _isar.articles.filter().feedIdEqualTo(id).deleteAll();
      await _isar.feeds.delete(id);
    });
  }
}
