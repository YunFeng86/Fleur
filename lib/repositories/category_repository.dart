import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../services/logging/app_logger.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

  static String _normalizeRemoteId(String remoteId) => remoteId.trim();

  Future<Category?> getById(int id) {
    return _isar.categorys.get(id);
  }

  Future<Category?> getByRemoteId(String remoteId) {
    final normalized = _normalizeRemoteId(remoteId);
    if (normalized.isEmpty) return Future.value(null);
    return _isar.categorys.filter().remoteIdEqualTo(normalized).findFirst();
  }

  Stream<Category?> watchById(int id) {
    return _isar.categorys.watchObject(id, fireImmediately: true);
  }

  Stream<List<Category>> watchAll() {
    return _isar.categorys.where().watch(fireImmediately: true);
  }

  Future<List<Category>> getAll() {
    return _isar.categorys.where().findAll();
  }

  Future<int> upsertByName(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Category name is empty');

    final existing = await _isar.categorys.filter().nameEqualTo(n).findFirst();
    final now = DateTime.now();
    final c = existing ?? Category()
      ..name = n;
    if (existing == null) c.createdAt = now;
    c.updatedAt = now;
    return _isar.writeTxn(() async => _isar.categorys.put(c));
  }

  Future<int> upsertRemote({
    required String remoteId,
    required String name,
  }) async {
    final normalizedRemoteId = _normalizeRemoteId(remoteId);
    if (normalizedRemoteId.isEmpty) {
      throw ArgumentError('Category remoteId is empty');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Category name is empty');
    }

    final byRemoteId = await getByRemoteId(normalizedRemoteId);
    final byName = await _isar.categorys
        .filter()
        .nameEqualTo(normalizedName)
        .findFirst();
    if (byRemoteId != null && byName != null && byName.id != byRemoteId.id) {
      await delete(byName.id);
    }

    return _isar.writeTxn(() async {
      final existing = byRemoteId == null
          ? await _isar.categorys
                .filter()
                .nameEqualTo(normalizedName)
                .findFirst()
          : await _isar.categorys.get(byRemoteId.id);
      final now = DateTime.now();
      final category = existing ?? Category()
        ..createdAt = now;
      category
        ..remoteId = normalizedRemoteId
        ..name = normalizedName
        ..updatedAt = now;
      return _isar.categorys.put(category);
    });
  }

  Future<void> deleteRemoteMissing(
    Set<String> seenRemoteIds, {
    bool allowEmptyPrune = false,
  }) async {
    final seen = seenRemoteIds
        .map(_normalizeRemoteId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final remoteCategories = await _isar.categorys
        .filter()
        .remoteIdIsNotNull()
        .findAll();
    if (seen.isEmpty && remoteCategories.isNotEmpty && !allowEmptyPrune) {
      AppLogger.w(
        'Skipped remote category prune because remote id list is empty',
        tag: 'sync',
        context: <String, Object?>{
          'remoteCategoryCount': remoteCategories.length,
        },
      );
      return;
    }
    for (final category in remoteCategories) {
      final remoteId = category.remoteId?.trim();
      if (remoteId == null || remoteId.isEmpty) continue;
      if (!seen.contains(remoteId)) {
        await delete(category.id);
      }
    }
  }

  Future<void> delete(int id) async {
    final feedIds = await _isar.feeds
        .filter()
        .categoryIdEqualTo(id)
        .idProperty()
        .findAll();
    if (feedIds.isNotEmpty) {
      const batchSize = 200;
      for (var i = 0; i < feedIds.length; i += batchSize) {
        final end = i + batchSize > feedIds.length
            ? feedIds.length
            : i + batchSize;
        final batchIds = feedIds.sublist(i, end);
        await _isar.writeTxn(() async {
          final feeds = await _isar.feeds.getAll(batchIds);
          final now = DateTime.now();
          final updates = <Feed>[];
          for (final f in feeds) {
            if (f == null) continue;
            f.categoryId = null;
            f.updatedAt = now;
            updates.add(f);
          }
          if (updates.isNotEmpty) {
            await _isar.feeds.putAll(updates);
          }

          // Keep denormalized Article.categoryId consistent with Feed.categoryId.
          final articleIds = await _isar.articles
              .filter()
              .anyOf(batchIds, (q, fid) => q.feedIdEqualTo(fid))
              .idProperty()
              .findAll();
          if (articleIds.isEmpty) return;

          const articleBatchSize = 200;
          for (var j = 0; j < articleIds.length; j += articleBatchSize) {
            final aEnd = j + articleBatchSize > articleIds.length
                ? articleIds.length
                : j + articleBatchSize;
            final aBatchIds = articleIds.sublist(j, aEnd);
            final items = await _isar.articles.getAll(aBatchIds);
            final aUpdates = <Article>[];
            for (final a in items) {
              if (a == null) continue;
              a.categoryId = null;
              a.updatedAt = now;
              aUpdates.add(a);
            }
            if (aUpdates.isNotEmpty) {
              await _isar.articles.putAll(aUpdates);
            }
          }
        });
      }
    }

    await _isar.writeTxn(() async {
      await _isar.categorys.delete(id);
    });
  }

  Future<void> rename(int id, String name) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Category name is empty');

    final existing = await _isar.categorys.filter().nameEqualTo(n).findFirst();
    if (existing != null && existing.id != id) {
      throw ArgumentError('Category name already exists');
    }

    await _isar.writeTxn(() async {
      final c = await _isar.categorys.get(id);
      if (c == null) return;
      c.name = n;
      c.updatedAt = DateTime.now();
      await _isar.categorys.put(c);
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
      final c = await _isar.categorys.get(id);
      if (c == null) return;

      if (updateFilterEnabled) c.filterEnabled = filterEnabled;
      if (updateFilterKeywords) c.filterKeywords = filterKeywords;
      if (updateSyncEnabled) c.syncEnabled = syncEnabled;
      if (updateSyncImages) c.syncImages = syncImages;
      if (updateSyncWebPages) c.syncWebPages = syncWebPages;
      if (updateShowAiSummary) c.showAiSummary = showAiSummary;
      if (updateAutoTranslate) c.autoTranslate = autoTranslate;

      c.updatedAt = DateTime.now();
      await _isar.categorys.put(c);
    });
  }
}
