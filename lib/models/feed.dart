import 'package:isar/isar.dart';

part 'feed.g.dart';

@collection
class Feed {
  Id id = Isar.autoIncrement;

  /// Subscription URL (RSS/Atom).
  @Index(unique: true, replace: true)
  late String url;

  String? title;
  String? siteUrl;
  String? description;

  @Index()
  int? categoryId;

  DateTime? lastSyncedAt;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

