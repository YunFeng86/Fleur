import 'package:isar_community/isar.dart';
import '../models/article.dart';
import '../models/tag.dart';
import '../utils/tag_colors.dart';

class TagRepository {
  TagRepository(this._isar);

  final Isar _isar;

  Future<List<Tag>> getAll() async {
    return _isar.tags.where().sortByName().findAll();
  }

  Stream<List<Tag>> watchAll() {
    return _isar.tags.where().sortByName().watch(fireImmediately: true);
  }

  Future<Tag> create(String name, {String? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name is empty');
    }

    return _isar.writeTxn(() async {
      final existing = await _isar.tags
          .filter()
          .nameEqualTo(trimmed, caseSensitive: false)
          .findFirst();

      if (existing != null) return existing;

      final now = DateTime.now();
      final tag = Tag()
        ..name = trimmed
        ..color = ensureTagColor(trimmed, color)
        ..createdAt = now
        ..updatedAt = now;

      await _isar.tags.put(tag);
      return tag;
    });
  }

  Future<void> delete(int id) async {
    final existing = await _isar.tags.get(id);
    if (existing == null) return;

    final articleIds = await _isar.articles
        .filter()
        .tags((t) => t.idEqualTo(id))
        .idProperty()
        .findAll();
    if (articleIds.isNotEmpty) {
      const batchSize = 200;
      for (var i = 0; i < articleIds.length; i += batchSize) {
        final end = (i + batchSize > articleIds.length)
            ? articleIds.length
            : i + batchSize;
        final batchIds = articleIds.sublist(i, end);
        await _isar.writeTxn(() async {
          final tag = await _isar.tags.get(id);
          if (tag == null) return;

          final items = await _isar.articles.getAll(batchIds);
          final updates = <Article>[];
          final now = DateTime.now();
          for (final a in items) {
            if (a == null) continue;
            a.tags.remove(tag);
            a.updatedAt = now;
            await a.tags.save();
            updates.add(a);
          }
          if (updates.isNotEmpty) {
            await _isar.articles.putAll(updates);
          }
        });
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _isar.writeTxn(() async {
      await _isar.tags.delete(id);
    });
  }
}
