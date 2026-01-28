import 'package:isar/isar.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

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
    final c = existing ?? Category()..name = n;
    if (existing == null) c.createdAt = now;
    c.updatedAt = now;
    return _isar.writeTxn(() async => _isar.categorys.put(c));
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
        final end =
            i + batchSize > feedIds.length ? feedIds.length : i + batchSize;
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
        });
      }
    }

    final articleIds = await _isar.articles
        .filter()
        .categoryIdEqualTo(id)
        .idProperty()
        .findAll();
    if (articleIds.isNotEmpty) {
      const batchSize = 200;
      for (var i = 0; i < articleIds.length; i += batchSize) {
        final end = i + batchSize > articleIds.length
            ? articleIds.length
            : i + batchSize;
        final batchIds = articleIds.sublist(i, end);
        await _isar.writeTxn(() async {
          final articles = await _isar.articles.getAll(batchIds);
          final now = DateTime.now();
          final updates = <Article>[];
          for (final a in articles) {
            if (a == null) continue;
            a.categoryId = null;
            a.updatedAt = now;
            updates.add(a);
          }
          if (updates.isNotEmpty) {
            await _isar.articles.putAll(updates);
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
}
