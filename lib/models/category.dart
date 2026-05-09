import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index()
  String? remoteId;

  @Index(unique: true, replace: true)
  late String name;

  /// Client-only category preferences. Remote-backed accounts keep these local
  /// instead of projecting them as remote category-structure changes.
  bool? filterEnabled;
  String? filterKeywords;

  /// Client-only sync/caching preferences.
  bool? syncEnabled;

  /// Whether to download images during sync
  bool? syncImages;

  /// Whether to download full web pages (Readability) during sync
  bool? syncWebPages;

  /// Whether to show AI summary
  bool? showAiSummary;

  /// Whether to auto-translate the article when opened in the reader.
  bool? autoTranslate;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
