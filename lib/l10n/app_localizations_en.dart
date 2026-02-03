// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutter Reader';

  @override
  String get notFound => 'Not found';

  @override
  String get settings => 'Settings';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get feeds => 'Feeds';

  @override
  String get saved => 'Saved';

  @override
  String get automate => 'Automate';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System language';

  @override
  String get english => 'English';

  @override
  String get chineseSimplified => '简体中文';

  @override
  String get chineseTraditional => '繁體中文';

  @override
  String get reader => 'Reader';

  @override
  String get fontSize => 'Font size';

  @override
  String get lineHeight => 'Line height';

  @override
  String get horizontalPadding => 'Horizontal padding';

  @override
  String get storage => 'Storage';

  @override
  String get clearImageCache => 'Clear image cache';

  @override
  String get clearImageCacheSubtitle =>
      'Remove cached images used for offline reading';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get tags => 'Tags';

  @override
  String get all => 'All Articles';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get refreshAll => 'Refresh all';

  @override
  String get refreshSelected => 'Refresh selected';

  @override
  String get importOpml => 'Import OPML';

  @override
  String get opmlParseFailed => 'Invalid OPML file';

  @override
  String get exportOpml => 'Export OPML';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get newCategory => 'New category';

  @override
  String get articles => 'Articles';

  @override
  String get unread => 'Unread';

  @override
  String get refreshConcurrency => 'Refresh Concurrency';

  @override
  String refreshingProgress(int current, int total) {
    return 'Refreshing $current/$total...';
  }

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get fullText => 'Full text';

  @override
  String get readerSettings => 'Reader settings';

  @override
  String get done => 'Done';

  @override
  String get more => 'More';

  @override
  String get showAll => 'Show all';

  @override
  String get unreadOnly => 'Unread only';

  @override
  String get selectAnArticle => 'Select an article';

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String unreadCountError(String error) {
    return 'Unread count error: $error';
  }

  @override
  String get refreshed => 'Refreshed';

  @override
  String get refreshedAll => 'Refreshed all';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get deleted => 'Deleted';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get name => 'Name';

  @override
  String get addedAndSynced => 'Added & synced';

  @override
  String get deleteSubscription => 'Delete subscription';

  @override
  String get deleteSubscriptionConfirmTitle => 'Delete subscription?';

  @override
  String get deleteSubscriptionConfirmContent =>
      'This will delete its cached articles too.';

  @override
  String get makeAvailableOffline => 'Make available offline';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get refresh => 'Refresh';

  @override
  String get moveToCategory => 'Move to category';

  @override
  String get noFeedsFoundInOpml => 'No feeds found in OPML';

  @override
  String importedFeeds(int count) {
    return 'Imported $count feeds';
  }

  @override
  String get exportedOpml => 'Exported OPML';

  @override
  String fullTextFailed(String error) {
    return 'Full text failed: $error';
  }

  @override
  String get scrollToLoadMore => 'Scroll to load more';

  @override
  String get noArticles => 'No articles';

  @override
  String get noUnreadArticles => 'No unread articles';

  @override
  String get star => 'Star';

  @override
  String get unstar => 'Unstar';

  @override
  String get starred => 'Starred';

  @override
  String get readLater => 'Read Later';

  @override
  String get markRead => 'Mark read';

  @override
  String get markUnread => 'Mark unread';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get autoMarkRead => 'Auto-mark as read when opened';

  @override
  String get search => 'Search';

  @override
  String get searchInContent => 'Search in content';

  @override
  String get groupingAndSorting => 'Grouping & Sorting';

  @override
  String get groupBy => 'Group by';

  @override
  String get groupNone => 'None';

  @override
  String get groupByDay => 'Day';

  @override
  String get sortOrder => 'Sort order';

  @override
  String get sortNewestFirst => 'Newest first';

  @override
  String get sortOldestFirst => 'Oldest first';

  @override
  String get rules => 'Rules';

  @override
  String get addRule => 'Add rule';

  @override
  String get editRule => 'Edit rule';

  @override
  String get ruleName => 'Rule name';

  @override
  String get keyword => 'Keyword';

  @override
  String get matchIn => 'Match in';

  @override
  String get matchTitle => 'Title';

  @override
  String get matchAuthor => 'Author';

  @override
  String get matchLink => 'Link';

  @override
  String get matchContent => 'Content';

  @override
  String get actions => 'Actions';

  @override
  String get autoStar => 'Auto-star';

  @override
  String get autoMarkReadAction => 'Auto mark as read';

  @override
  String get enabled => 'Enabled';

  @override
  String get rename => 'Rename';

  @override
  String get edit => 'Edit';

  @override
  String get nameAlreadyExists => 'Name already exists';

  @override
  String get lastChecked => 'Last checked';

  @override
  String get lastSynced => 'Last synced';

  @override
  String get never => 'Never';

  @override
  String get cleanupReadArticles => 'Cleanup read articles';

  @override
  String get cleanupNow => 'Run cleanup';

  @override
  String cachingArticles(int count) {
    return 'Caching $count articles...';
  }

  @override
  String get showNotification => 'Show notification';

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get newTag => 'New Tag';

  @override
  String get tagColor => 'Tag color';

  @override
  String get autoColor => 'Auto';

  @override
  String cleanedArticles(int count) {
    return 'Cleaned $count articles';
  }

  @override
  String days(int days) {
    return '$days days';
  }

  @override
  String get services => 'Services';

  @override
  String get autoRefresh => 'Auto refresh';

  @override
  String get autoRefreshSubtitle => 'Automatically refresh feeds in background';

  @override
  String get off => 'Off';

  @override
  String everyMinutes(int minutes) {
    return 'Every $minutes min';
  }

  @override
  String get appPreferences => 'App Preferences';

  @override
  String get about => 'About';

  @override
  String get dataDirectory => 'Data directory';

  @override
  String get copyPath => 'Copy path';

  @override
  String get openFolder => 'Open folder';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get filter => 'Filter';

  @override
  String get filterKeywordsHint =>
      'Add reserved keywords (separate with \";\", connect multiple with \"+\")';

  @override
  String get sync => 'Sync';

  @override
  String get enableSync => 'Enable Sync';

  @override
  String get enableFilter => 'Enable Filter';

  @override
  String get syncAlwaysEnabled =>
      'Always enabled (Settings - Sync - Sync Mode is \"All\")';

  @override
  String get syncImages => 'Download Images during Sync';

  @override
  String get syncWebPages => 'Download Web Pages during Sync';

  @override
  String get showAiSummary => 'Show AI Summary';

  @override
  String get showImageTitle => 'Show Image Title';

  @override
  String get showAttachedImage => 'Show Attached Image';

  @override
  String get htmlDecoding => 'HTML Decoding';

  @override
  String get mobilizer => 'Mobilizer';

  @override
  String get inherit => 'Inherit';

  @override
  String get auto => 'Auto';

  @override
  String get autoOn => 'Auto (On)';

  @override
  String get autoOff => 'Off';

  @override
  String get defaultValue => 'Default Value';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get rssUserAgent => 'RSS/Atom User-Agent';

  @override
  String get webUserAgent => 'Web Page User-Agent';

  @override
  String get userAgentRssHint => 'Used when fetching RSS/Atom feeds.';

  @override
  String get userAgentWebHint =>
      'Used when fetching full web pages (Readability).';

  @override
  String get resetToDefault => 'Reset to default';
}
