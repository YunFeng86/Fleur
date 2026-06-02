// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleur';

  @override
  String get notFound => 'Not found';

  @override
  String get openFailedGeneral =>
      'Couldn\'t open this location. Check permissions and try again.';

  @override
  String get macosMenuLanguageRestartHint =>
      'Menu bar language may require restarting the app to fully apply.';

  @override
  String pathNotFound(Object path) {
    return 'Path does not exist: $path';
  }

  @override
  String get settings => 'Settings';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsSearchNoResults => 'No settings match this search.';

  @override
  String get settingsSearchPageLabel => 'Page';

  @override
  String get settingsSearchSectionLabel => 'Section';

  @override
  String get settingsSearchSettingLabel => 'Setting';

  @override
  String settingsSearchResultCount(Object count) {
    return '$count results';
  }

  @override
  String get feeds => 'Feeds';

  @override
  String get saved => 'Saved';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get dynamicColor => 'Dynamic colors';

  @override
  String get dynamicColorSubtitle =>
      'Follow system dynamic or accent colors when available';

  @override
  String get seedColorPreset => 'Theme colors';

  @override
  String get seedColorPresetSubtitle =>
      'Used when dynamic colors are off/unavailable';

  @override
  String get seedColorBlue => 'Blue';

  @override
  String get seedColorGreen => 'Green';

  @override
  String get seedColorPurple => 'Purple';

  @override
  String get seedColorOrange => 'Orange';

  @override
  String get seedColorPink => 'Pink';

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
  String get defaultsGroup => 'Global';

  @override
  String get folders => 'Subscriptions';

  @override
  String get globalDefaults => 'Global defaults';

  @override
  String get allSubscriptions => 'All subscriptions';

  @override
  String get manage => 'Manage';

  @override
  String get overview => 'Overview';

  @override
  String get categoriesLabel => 'Categories';

  @override
  String get globalDefaultsDescription =>
      'Applied when a folder or subscription does not override a setting.';

  @override
  String get allSubscriptionsDescription =>
      'Review the overall subscription structure and pick a subscription to edit.';

  @override
  String get uncategorizedDescription =>
      'Subscriptions without a folder inherit the global defaults until overridden.';

  @override
  String get tags => 'Tags';

  @override
  String get all => 'All Articles';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get refreshAll => 'Refresh sources';

  @override
  String get refreshFeed => 'Refresh feed';

  @override
  String get refreshCategory => 'Refresh category';

  @override
  String get refreshFeedAndSync => 'Refresh feed and sync';

  @override
  String get refreshCategoryAndSync => 'Refresh category and sync';

  @override
  String get refreshSourcesAndSync => 'Refresh sources and sync';

  @override
  String get accountSync => 'Account sync';

  @override
  String get accountSyncSubtitle =>
      'Sync this remote account in the background.';

  @override
  String get syncAccount => 'Sync account';

  @override
  String get syncingAccount => 'Syncing account...';

  @override
  String get syncedAccount => 'Account synced';

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
  String get selectCategory => 'Select a category';

  @override
  String get loadingCategories => 'Loading categories...';

  @override
  String get creatingCategory => 'Creating category...';

  @override
  String get feverAddSubscriptionNotSupported =>
      'Fever accounts don\'t support adding subscriptions. Please manage subscriptions on the server.';

  @override
  String get remoteCommandRequiresConnectivity =>
      'This action requires connectivity to the remote service.';

  @override
  String get remoteCommandRequiresAuthentication =>
      'The remote service rejected the current account credentials. Check the account settings and try again.';

  @override
  String get remoteCommandNeedsRefresh =>
      'The remote service could not match the current feed or category. Sync and try again.';

  @override
  String get remoteCommandRejected =>
      'The remote service rejected this action. Review the request and try again.';

  @override
  String get remoteCommandUnavailable =>
      'The remote service could not complete this action right now. Try again later.';

  @override
  String get remoteCommandNotSupported =>
      'This remote account does not support this action.';

  @override
  String get remoteCommandRequiresCategory =>
      'This remote account requires a server-side category for the subscription.';

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
  String get fullTextRetry => 'Full text failed. Retry';

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
  String get readerEmptySubtitle =>
      'Open an article from the list to read it here.';

  @override
  String get savedReaderEmptyTitle => 'Select a saved article';

  @override
  String get savedReaderEmptySubtitle =>
      'Open an article from Saved or Read Later.';

  @override
  String get searchReaderEmptyTitle => 'Select a search result';

  @override
  String get searchReaderEmptySubtitle =>
      'Enter a keyword, then open a result from the list.';

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
  String get refreshedAndSynced => 'Refreshed and synced';

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
  String get feedOrWebsiteUrl => 'Feed / website URL';

  @override
  String get feedOrWebsiteUrlHint => 'Paste a website or RSS URL';

  @override
  String get findFeeds => 'Find feeds';

  @override
  String get discoveringFeeds => 'Discovering feeds...';

  @override
  String get addingSubscription => 'Adding subscription...';

  @override
  String get selectFeed => 'Select a feed';

  @override
  String get noFeedsFound => 'No feeds found';

  @override
  String get noFeedsFoundHint =>
      'Paste the RSS/Atom URL directly or try another page from the site.';

  @override
  String get subscriptionPreview => 'Source preview';

  @override
  String subscriptionResultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count subscription sources',
      one: 'Found 1 subscription source',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPreviewUnavailable =>
      'No recent preview items available';

  @override
  String get feedSourceDirect => 'RSS/Atom URL';

  @override
  String get feedSourceAlternate => 'Discovered on page';

  @override
  String get feedSourceCommonPath => 'Common feed path';

  @override
  String get name => 'Name';

  @override
  String get addedAndSynced => 'Added & synced';

  @override
  String get subscriptionAddedTitle => 'Subscription added';

  @override
  String get subscriptionAddedMessage =>
      'The subscription was added. You can open it now or keep adding more.';

  @override
  String get subscriptionRefreshWarning =>
      'The subscription was added, but the first refresh failed. You can retry refresh later.';

  @override
  String get subscriptionAlreadyExistsTitle => 'Already subscribed';

  @override
  String get subscriptionAlreadyExistsMessage =>
      'This feed is already in your subscriptions. No category changes were made.';

  @override
  String get viewSubscription => 'View subscription';

  @override
  String get continueAddingSubscription => 'Continue adding';

  @override
  String get moveToCurrentCategory => 'Move to current category';

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
  String get deleteCategoryConfirmTitle => 'Delete category?';

  @override
  String get deleteCategoryConfirmContent =>
      'Feeds in this category will be moved to Uncategorized.';

  @override
  String get remoteDeleteCategoryConfirmContent =>
      'Delete this category on the remote service and then reconcile the local mirror.';

  @override
  String get remoteWritableTaxonomyTitle => 'Remote categories';

  @override
  String get remoteWritableTaxonomyDescription =>
      'Category changes are applied on the remote service and then mirrored locally.';

  @override
  String get remoteReadOnlyTaxonomyTitle => 'Read-only remote groups';

  @override
  String get remoteReadOnlyTaxonomyDescription =>
      'These categories mirror read-only remote groups. Rename, delete, or move items in the remote service.';

  @override
  String get feedCategoryReadOnlyTaxonomyTitle => 'Category managed remotely';

  @override
  String get feedCategoryReadOnlyTaxonomyDescription =>
      'This feed\'s category comes from a read-only remote group mirror.';

  @override
  String get deleteTagConfirmTitle => 'Delete tag?';

  @override
  String get deleteTagConfirmContent =>
      'This will remove it from all articles.';

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
  String get noStarredArticles => 'No starred articles yet';

  @override
  String get noReadLaterArticles => 'No read-later articles yet';

  @override
  String get noUnreadArticles => 'No unread articles';

  @override
  String get articleListEmptySubtitle =>
      'Add a subscription or refresh sources, and articles will appear here.';

  @override
  String get unreadEmptySubtitle =>
      'Everything in the current scope has been read.';

  @override
  String get savedSearchEmptySubtitle => 'No saved articles match this search.';

  @override
  String get star => 'Star';

  @override
  String get unstar => 'Unstar';

  @override
  String get starred => 'Starred';

  @override
  String get readLater => 'Read Later';

  @override
  String get removeReadLater => 'Remove from Read Later';

  @override
  String get openArticle => 'Open article';

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
  String get copyLink => 'Copy link';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get share => 'Share';

  @override
  String get autoMarkRead => 'Auto-mark as read when opened';

  @override
  String get search => 'Search';

  @override
  String get searchInContent => 'Search in content';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get searchStartTitle => 'Start searching';

  @override
  String get searchStartSubtitle =>
      'Enter keywords to search titles, summaries, and content.';

  @override
  String searchNoResultsSubtitle(Object query) {
    return 'No articles match “$query”.';
  }

  @override
  String get articleNotFoundSubtitle =>
      'This article may have been deleted or is no longer available locally.';

  @override
  String get findInPage => 'Find in page';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get caseSensitive => 'Case sensitive';

  @override
  String get close => 'Close';

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
  String get manageTags => 'Manage Tags';

  @override
  String get newTag => 'New Tag';

  @override
  String get tagColor => 'Tag color';

  @override
  String get autoColor => 'Auto';

  @override
  String get tagsLoadingError => 'Error loading tags';

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
  String get account => 'Account';

  @override
  String get addOrRegisterAccount => 'Add or register account';

  @override
  String get local => 'Local';

  @override
  String get miniflux => 'Miniflux';

  @override
  String get fever => 'Fever';

  @override
  String get addLocal => 'Add Local';

  @override
  String get addLocalAccount => 'Add Local Account';

  @override
  String get addMiniflux => 'Add Miniflux';

  @override
  String get addFever => 'Add Fever';

  @override
  String get minifluxStrategy => 'Miniflux strategy';

  @override
  String get minifluxStrategySubtitle =>
      'Controls how much data is fetched/prefetched during sync.';

  @override
  String get remoteSyncStrategy => 'Remote sync strategy';

  @override
  String get remoteSyncStrategySubtitle =>
      'Controls the remote article window pulled during sync.';

  @override
  String get remoteSyncStrategyMinifluxSubtitle =>
      'Miniflux can page through remote entries up to this per-sync window.';

  @override
  String get remoteSyncStrategyFeverSubtitle =>
      'Fever syncs unread and saved items, capped by this per-sync window.';

  @override
  String get remoteEntriesLimit => 'Entries per sync';

  @override
  String get remoteFetchConcurrency => 'Remote fetch concurrency';

  @override
  String get remoteFetchConcurrencySubtitle =>
      'Controls concurrent remote article batch requests during account sync.';

  @override
  String get minifluxWebFetchMode => 'Web page fetching';

  @override
  String get minifluxWebFetchModeSubtitle =>
      'When \"Download Web Pages during Sync\" is enabled.';

  @override
  String get minifluxWebFetchModeClient => 'Client (Readability)';

  @override
  String get minifluxWebFetchModeServer => 'Server (Miniflux fetch-content)';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get fieldName => 'Name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlRequired => 'Enter base URL';

  @override
  String get minifluxBaseUrlHint => 'https://miniflux.example.com';

  @override
  String get feverBaseUrlHint => 'https://example.com/fever/';

  @override
  String get apiToken => 'API Token';

  @override
  String get apiTokenRequired => 'Enter API token';

  @override
  String get apiKey => 'API Key';

  @override
  String get appId => 'App ID';

  @override
  String get appKey => 'App Key';

  @override
  String get apiKeyRequired => 'Enter API key';

  @override
  String get authenticationMethod => 'Authentication method';

  @override
  String get usernamePassword => 'Username & password';

  @override
  String get minifluxAuthHint =>
      'Use an API token (recommended) or username/password.';

  @override
  String get feverAuthHint =>
      'Use an API key (recommended) or username/password.';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Enter username';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Enter password';

  @override
  String get defaultModel => 'Default model';

  @override
  String get savedApiKeyClearHint => 'Leave blank to clear the saved API key.';

  @override
  String get savedCredentialsClearHint =>
      'Leave blank to clear the saved credentials.';

  @override
  String get aiServicesEmptyState => 'No AI services added yet.';

  @override
  String modelSummary(String model) {
    return 'Model: $model';
  }

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get missingRequiredFields => 'Missing required fields';

  @override
  String get invalidBaseUrl => 'Invalid base URL';

  @override
  String get onlySupportedInLocalAccount => 'Only supported in Local account';

  @override
  String get autoRefresh => 'Auto source refresh';

  @override
  String get autoRefreshSubtitle =>
      'Refresh subscription sources at the selected interval. Mobile background refresh is system scheduled, usually no more often than every 15 minutes, and may not run exactly on time.';

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
  String get logDirectory => 'Log directory';

  @override
  String get openLog => 'Open log';

  @override
  String get openLogFolder => 'Open log folder';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get exportedLogs => 'Logs exported';

  @override
  String get noLogsFound => 'No log files found';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get version => 'Version';

  @override
  String get buildNumber => 'Build number';

  @override
  String get openSourceLicense => 'Open source license';

  @override
  String get viewLicense => 'View license';

  @override
  String get thirdPartyLicenses => 'Third-party licenses';

  @override
  String get viewThirdPartyLicenses => 'View all open source licenses';

  @override
  String get licenseLoadFailed => 'Failed to load license.';

  @override
  String get mitLicenseName => 'MIT License';

  @override
  String get shortcutNextPreviousArticle => 'J / K: Next / previous article';

  @override
  String get shortcutRefreshCurrentSelection =>
      'R: Refresh (current selection)';

  @override
  String get shortcutToggleUnreadOnly => 'U: Toggle unread-only';

  @override
  String get shortcutToggleReadUnreadSelectedArticle =>
      'M: Toggle read/unread for selected article';

  @override
  String get shortcutToggleStarSelectedArticle =>
      'S: Toggle star for selected article';

  @override
  String get shortcutSearchArticlesAndFindInPage =>
      'Ctrl/Cmd+F: Search articles (list); focus Find in page (reader)';

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
  String get syncStatusSyncing => 'Syncing';

  @override
  String get syncStatusSyncingFeeds => 'Syncing feeds';

  @override
  String get syncStatusSyncingSubscriptions => 'Syncing subscriptions';

  @override
  String get syncStatusSyncingUnreadArticles => 'Syncing unread articles';

  @override
  String get syncStatusUploadingChanges => 'Uploading changes';

  @override
  String get syncStatusCompleted => 'Sync complete';

  @override
  String get syncStatusFailed => 'Sync failed';

  @override
  String get showAiSummary => 'Show Summary';

  @override
  String get summary => 'Summary';

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
  String get defaultOption => 'Default';

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

  @override
  String get notificationNewArticleTitle => 'New Article';

  @override
  String get notificationNewArticlesTitle => 'New Articles';

  @override
  String notificationNewArticlesBody(int count) {
    return 'Found $count new articles';
  }

  @override
  String get notificationNewArticlesChannelName => 'New Articles';

  @override
  String get notificationNewArticlesChannelDescription =>
      'Notifications for new articles found during sync';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get translationAndAiServices => 'Translation & AI';

  @override
  String get translation => 'Translation';

  @override
  String get translationProvider => 'Translation provider';

  @override
  String get aiServices => 'AI services';

  @override
  String get addAiService => 'Add AI service';

  @override
  String get aiService => 'AI service';

  @override
  String get aiSummary => 'AI summary';

  @override
  String get aiSummaryService => 'AI summary service';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get followAppLanguage => 'Follow app language';

  @override
  String get translationProviderGoogleWeb => 'Google Translate (web)';

  @override
  String get translationProviderBingWeb => 'Bing Translate (web)';

  @override
  String get translationProviderBaiduApi => 'Baidu Translate (API)';

  @override
  String get translationProviderDeepLApi => 'DeepL (API)';

  @override
  String get translationProviderDeepLX => 'DeepLX';

  @override
  String translationProviderAiService(Object name) {
    return 'AI: $name';
  }

  @override
  String get translationProviderBaiduApiSubtitle =>
      'Configure App ID / App Key';

  @override
  String get deepLXBaseUrlTitle => 'DeepLX Base URL';

  @override
  String get deepLEndpoint => 'Endpoint';

  @override
  String get deepLEndpointFree => 'Free';

  @override
  String get deepLEndpointPro => 'Pro';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get defaultAlreadySet => 'Default (already set)';

  @override
  String get aiSummaryPrompt => 'AI summary prompt';

  @override
  String get aiTranslationPrompt => 'AI translation prompt';

  @override
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Please summarize this article in $language (title: $title): $content';
  }

  @override
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  ) {
    return 'Please translate this article fragment into $language (title: $title): $content';
  }

  @override
  String get promptVariables => 'Available variables';

  @override
  String get promptVariableContentDescription => 'Article content';

  @override
  String get promptVariableLanguageDescription => 'Target language';

  @override
  String get promptVariableTitleDescription => 'Article title';

  @override
  String get tpmLimit => 'TPM limit';

  @override
  String get tpmLimitSubtitle =>
      '0 means unlimited; requests will be queued when exceeded.';

  @override
  String get aiSummaryAction => 'AI summary';

  @override
  String get translateAction => 'Translate';

  @override
  String get translationMode => 'Translation mode';

  @override
  String get immersiveTranslation => 'Immersive translation';

  @override
  String get traditionalTranslation => 'Traditional translation';

  @override
  String get generating => 'Generating…';

  @override
  String get queued => 'Queued';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get cachedPromptOutdated => 'Prompt updated; regenerate to refresh.';

  @override
  String languageMismatchBanner(Object source, Object target) {
    return 'Detected $source content; target language is $target.';
  }

  @override
  String get dontRemindThisLanguage => 'Don\'t remind for this language';

  @override
  String get autoAiSummary => 'Auto AI summary';

  @override
  String get autoTranslate => 'Auto translate';

  @override
  String get aiNotConfigured => 'AI service not configured.';

  @override
  String get translationNotAvailable =>
      'Translation is not available for the selected provider.';

  @override
  String get clearTranslation => 'Clear translation';

  @override
  String get dbRecoveryTitle => 'Database recovery';

  @override
  String get dbRecoveryDescription =>
      'The app detected a database issue and performed recovery. Your data was preserved on disk (backup / moved file).';

  @override
  String get dbRecoveryTimeLabel => 'Time';

  @override
  String get dbRecoveryDbNameLabel => 'DB name';

  @override
  String get dbRecoveryOpenedAsLabel => 'Opened as';

  @override
  String get dbRecoveryBackupPathLabel => 'Backup';

  @override
  String get dbRecoveryMovedOriginalPathLabel => 'Moved original';

  @override
  String get dbRecoveryErrorLabel => 'Error';

  @override
  String get dbRecoveryDataPreservedHint =>
      'Tip: Use the copy buttons to copy paths for troubleshooting or support.';
}
