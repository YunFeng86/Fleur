import 'package:isar/isar.dart';

part 'tag.g.dart';

@collection
class Tag {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String name;

  /// Hex color string (e.g. #FF0000)
  String? color;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
