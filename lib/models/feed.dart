import 'package:isar_community/isar.dart';

part 'feed.g.dart';

@collection
class Feed {
  Id id = Isar.autoIncrement;

  @Index()
  String? remoteId;

  /// Subscription URL (RSS/Atom).
  @Index(unique: true, replace: true)
  late String url;

  String? title;

  /// User-defined display title. When set, it takes precedence over `title`
  /// parsed from the feed.
  String? userTitle;
  String? siteUrl;
  String? description;

  /// HTTP caching headers from the last successful fetch. Used to perform
  /// conditional requests (ETag / If-Modified-Since) for faster refresh.
  String? etag;
  String? lastModified;

  @Index()
  int? categoryId;

  /// Last time we attempted to check this feed (200/304).
  DateTime? lastCheckedAt;

  /// Last successful sync time when the feed content was updated (200).
  DateTime? lastSyncedAt;

  /// Last HTTP status code for the feed fetch (e.g. 200/304/4xx/5xx when known).
  int? lastStatusCode;

  /// Last refresh duration in milliseconds (best-effort).
  int? lastDurationMs;

  /// Number of incoming items observed on last refresh (best-effort).
  int? lastIncomingCount;

  /// Last error message (best-effort). Cleared on success.
  String? lastError;
  DateTime? lastErrorAt;

  /// Client-only feed preferences. Remote-backed accounts keep these local
  /// instead of projecting them as remote subscription-structure changes.
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
