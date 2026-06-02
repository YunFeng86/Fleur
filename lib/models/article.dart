import 'package:isar_community/isar.dart';

import 'tag.dart';

part 'article.g.dart';

enum ContentSource { feed, extracted, extractionFailed }

/// Preferred content view mode in Reader UI.
///
/// Note: This is a user preference (which mode to show by default), not the
/// actual availability of content.
enum ArticleContentView { feed, extracted }

@collection
class Article {
  Id id = Isar.autoIncrement;

  @Index()
  late int feedId;

  /// Denormalized categoryId from Feed for fast filtering without JOIN.
  /// Updated when Feed.categoryId changes.
  /// Composite index with publishedAt for optimized category-based queries.
  @Index(composite: [CompositeIndex('publishedAt')])
  int? categoryId;

  /// Best-effort remote identifier (guid/id/link). Not guaranteed to be present.
  @Index(composite: [CompositeIndex('feedId')])
  String? remoteId;

  @Index(composite: [CompositeIndex('feedId')], unique: true, replace: true)
  late String link;

  /// Content hash (MD5/SHA256) for detecting article updates.
  /// Computed from contentHtml during sync.
  String? contentHash;

  String? title;
  String? author;

  /// 来自 Feed 的 HTML 内容。
  String? contentHtml;

  /// 提取后的 HTML 内容。
  String? extractedContentHtml;

  /// 内容来源状态。
  @enumerated
  ContentSource contentSource = ContentSource.feed;

  /// Reader 默认显示哪种内容（持久化用户选择）。
  @enumerated
  ArticleContentView preferredContentView = ArticleContentView.feed;

  /// Key for pagination/sorting.
  /// Composite index with categoryId for optimized time-based queries per category.
  @Index()
  DateTime publishedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @Index()
  bool isRead = false;

  @Index()
  bool isStarred = false;

  @Index()
  bool isReadLater = false;

  final tags = IsarLinks<Tag>();

  DateTime fetchedAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
