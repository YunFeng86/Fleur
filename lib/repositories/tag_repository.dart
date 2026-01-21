import 'package:isar/isar.dart';
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
    return _isar.writeTxn(() async {
      await _isar.tags.delete(id);
    });
  }
}
