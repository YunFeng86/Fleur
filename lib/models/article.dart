import 'package:isar/isar.dart';

part 'article.g.dart';

@collection
class Article {
  Id id = Isar.autoIncrement;

  @Index()
  late int feedId;

  /// Best-effort remote identifier (guid/id/link). Not guaranteed to be present.
  @Index(composite: [CompositeIndex('feedId')])
  String? remoteId;

  @Index(composite: [CompositeIndex('feedId')], unique: true, replace: true)
  late String link;

  String? title;
  String? author;

  /// HTML from the feed itself (description/content).
  String? contentHtml;

  /// Full content extracted locally (Smart Reader View).
  String? fullContentHtml;

  /// Key for pagination/sorting.
  @Index()
  DateTime publishedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @Index()
  bool isRead = false;

  @Index()
  bool isStarred = false;

  DateTime fetchedAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
