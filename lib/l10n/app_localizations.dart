import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// appTitle
  ///
  /// In en, this message translates to:
  /// **'Fleur'**
  String get appTitle;

  /// notFound
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// openFailedGeneral
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this location. Check permissions and try again.'**
  String get openFailedGeneral;

  /// macosMenuLanguageRestartHint
  ///
  /// In en, this message translates to:
  /// **'Menu bar language may require restarting the app to fully apply.'**
  String get macosMenuLanguageRestartHint;

  /// pathNotFound
  ///
  /// In en, this message translates to:
  /// **'Path does not exist: {path}'**
  String pathNotFound(Object path);

  /// settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Placeholder for the settings page search field
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// Empty state text for the settings page search results
  ///
  /// In en, this message translates to:
  /// **'No settings match this search.'**
  String get settingsSearchNoResults;

  /// Settings search result type label for top-level pages
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get settingsSearchPageLabel;

  /// Settings search result type label for settings sections
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get settingsSearchSectionLabel;

  /// Settings search result type label for individual settings
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get settingsSearchSettingLabel;

  /// Settings search result count badge
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String settingsSearchResultCount(Object count);

  /// Global navigation label: feeds
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get feeds;

  /// Global navigation label: saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Placeholder text
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// theme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Theme mode selector label
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Use Material You dynamic colors when available
  ///
  /// In en, this message translates to:
  /// **'Dynamic colors'**
  String get dynamicColor;

  /// Hint for dynamic colors setting
  ///
  /// In en, this message translates to:
  /// **'Use Material You colors (Android 12+)'**
  String get dynamicColorSubtitle;

  /// Seed color preset selector label
  ///
  /// In en, this message translates to:
  /// **'Theme colors'**
  String get seedColorPreset;

  /// Seed color preset selector hint
  ///
  /// In en, this message translates to:
  /// **'Used when dynamic colors are off/unavailable'**
  String get seedColorPresetSubtitle;

  /// Seed color preset name
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get seedColorBlue;

  /// Seed color preset name
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get seedColorGreen;

  /// Seed color preset name
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get seedColorPurple;

  /// Seed color preset name
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get seedColorOrange;

  /// Seed color preset name
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get seedColorPink;

  /// language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// systemLanguage
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// english
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// chineseSimplified
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get chineseSimplified;

  /// chineseTraditional
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get chineseTraditional;

  /// reader
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get reader;

  /// fontSize
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// lineHeight
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeight;

  /// horizontalPadding
  ///
  /// In en, this message translates to:
  /// **'Horizontal padding'**
  String get horizontalPadding;

  /// storage
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// clearImageCache
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get clearImageCache;

  /// clearImageCacheSubtitle
  ///
  /// In en, this message translates to:
  /// **'Remove cached images used for offline reading'**
  String get clearImageCacheSubtitle;

  /// cacheCleared
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// subscriptions
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// Section label for default settings entries
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get defaultsGroup;

  /// Section label for subscription folders
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get folders;

  /// Entry label for subscription-wide default settings
  ///
  /// In en, this message translates to:
  /// **'Global defaults'**
  String get globalDefaults;

  /// Entry label for the full subscription scope
  ///
  /// In en, this message translates to:
  /// **'All subscriptions'**
  String get allSubscriptions;

  /// Toolbar label for the management actions menu
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// Overview section label
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Summary label for categories count
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesLabel;

  /// Description shown for the global defaults pane
  ///
  /// In en, this message translates to:
  /// **'Applied when a folder or subscription does not override a setting.'**
  String get globalDefaultsDescription;

  /// Description shown for the all subscriptions overview
  ///
  /// In en, this message translates to:
  /// **'Review the overall subscription structure and pick a subscription to edit.'**
  String get allSubscriptionsDescription;

  /// Description shown for the uncategorized overview
  ///
  /// In en, this message translates to:
  /// **'Subscriptions without a folder inherit the global defaults until overridden.'**
  String get uncategorizedDescription;

  /// tags
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// all
  ///
  /// In en, this message translates to:
  /// **'All Articles'**
  String get all;

  /// uncategorized
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// refreshAll
  ///
  /// In en, this message translates to:
  /// **'Refresh sources'**
  String get refreshAll;

  /// Tooltip for refreshing the currently selected feed
  ///
  /// In en, this message translates to:
  /// **'Refresh feed'**
  String get refreshFeed;

  /// Tooltip for refreshing the currently selected category
  ///
  /// In en, this message translates to:
  /// **'Refresh category'**
  String get refreshCategory;

  /// Tooltip for refreshing the selected remote feed source and syncing the account
  ///
  /// In en, this message translates to:
  /// **'Refresh feed and sync'**
  String get refreshFeedAndSync;

  /// Tooltip for refreshing selected remote category sources and syncing the account
  ///
  /// In en, this message translates to:
  /// **'Refresh category and sync'**
  String get refreshCategoryAndSync;

  /// Tooltip for refreshing remote subscription sources and syncing the account
  ///
  /// In en, this message translates to:
  /// **'Refresh sources and sync'**
  String get refreshSourcesAndSync;

  /// accountSync
  ///
  /// In en, this message translates to:
  /// **'Account sync'**
  String get accountSync;

  /// accountSyncSubtitle
  ///
  /// In en, this message translates to:
  /// **'Sync this remote account in the background.'**
  String get accountSyncSubtitle;

  /// syncAccount
  ///
  /// In en, this message translates to:
  /// **'Sync account'**
  String get syncAccount;

  /// syncingAccount
  ///
  /// In en, this message translates to:
  /// **'Syncing account...'**
  String get syncingAccount;

  /// syncedAccount
  ///
  /// In en, this message translates to:
  /// **'Account synced'**
  String get syncedAccount;

  /// refreshSelected
  ///
  /// In en, this message translates to:
  /// **'Refresh selected'**
  String get refreshSelected;

  /// importOpml
  ///
  /// In en, this message translates to:
  /// **'Import OPML'**
  String get importOpml;

  /// opmlParseFailed
  ///
  /// In en, this message translates to:
  /// **'Invalid OPML file'**
  String get opmlParseFailed;

  /// exportOpml
  ///
  /// In en, this message translates to:
  /// **'Export OPML'**
  String get exportOpml;

  /// addSubscription
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// selectCategory
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// loadingCategories
  ///
  /// In en, this message translates to:
  /// **'Loading categories...'**
  String get loadingCategories;

  /// creatingCategory
  ///
  /// In en, this message translates to:
  /// **'Creating category...'**
  String get creatingCategory;

  /// feverAddSubscriptionNotSupported
  ///
  /// In en, this message translates to:
  /// **'Fever accounts don\'t support adding subscriptions. Please manage subscriptions on the server.'**
  String get feverAddSubscriptionNotSupported;

  /// Shown when a remote-backed structure command needs online access.
  ///
  /// In en, this message translates to:
  /// **'This action requires connectivity to the remote service.'**
  String get remoteCommandRequiresConnectivity;

  /// Shown when a remote-backed structure command fails because the current credentials are invalid or missing.
  ///
  /// In en, this message translates to:
  /// **'The remote service rejected the current account credentials. Check the account settings and try again.'**
  String get remoteCommandRequiresAuthentication;

  /// Shown when a remote-backed structure command cannot resolve the current remote target.
  ///
  /// In en, this message translates to:
  /// **'The remote service could not match the current feed or category. Sync and try again.'**
  String get remoteCommandNeedsRefresh;

  /// Shown when a remote-backed structure command is rejected by the remote service for request-specific reasons.
  ///
  /// In en, this message translates to:
  /// **'The remote service rejected this action. Review the request and try again.'**
  String get remoteCommandRejected;

  /// Shown when a remote-backed structure command fails because the remote service is temporarily unavailable.
  ///
  /// In en, this message translates to:
  /// **'The remote service could not complete this action right now. Try again later.'**
  String get remoteCommandUnavailable;

  /// Shown when the active remote provider cannot perform a structure-management command.
  ///
  /// In en, this message translates to:
  /// **'This remote account does not support this action.'**
  String get remoteCommandNotSupported;

  /// Shown when a remote-backed feed cannot be moved to an uncategorized state.
  ///
  /// In en, this message translates to:
  /// **'This remote account requires a server-side category for the subscription.'**
  String get remoteCommandRequiresCategory;

  /// newCategory
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// articles
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get articles;

  /// unread
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// refreshConcurrency
  ///
  /// In en, this message translates to:
  /// **'Refresh Concurrency'**
  String get refreshConcurrency;

  /// No description provided for @refreshingProgress.
  ///
  /// In en, this message translates to:
  /// **'Refreshing {current}/{total}...'**
  String refreshingProgress(int current, int total);

  /// markAllRead
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// fullText
  ///
  /// In en, this message translates to:
  /// **'Full text'**
  String get fullText;

  /// fullTextRetry
  ///
  /// In en, this message translates to:
  /// **'Full text failed. Retry'**
  String get fullTextRetry;

  /// readerSettings
  ///
  /// In en, this message translates to:
  /// **'Reader settings'**
  String get readerSettings;

  /// done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// more
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// showAll
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// unreadOnly
  ///
  /// In en, this message translates to:
  /// **'Unread only'**
  String get unreadOnly;

  /// selectAnArticle
  ///
  /// In en, this message translates to:
  /// **'Select an article'**
  String get selectAnArticle;

  /// Reader pane helper text when no article is selected
  ///
  /// In en, this message translates to:
  /// **'Open an article from the list to read it here.'**
  String get readerEmptySubtitle;

  /// Reader pane title when the saved section has no selected article
  ///
  /// In en, this message translates to:
  /// **'Select a saved article'**
  String get savedReaderEmptyTitle;

  /// Reader pane helper text for the saved section
  ///
  /// In en, this message translates to:
  /// **'Open an article from Saved or Read Later.'**
  String get savedReaderEmptySubtitle;

  /// Reader pane title when the search section has no selected article
  ///
  /// In en, this message translates to:
  /// **'Select a search result'**
  String get searchReaderEmptyTitle;

  /// Reader pane helper text for the search section
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword, then open a result from the list.'**
  String get searchReaderEmptySubtitle;

  /// errorMessage
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// unreadCountError
  ///
  /// In en, this message translates to:
  /// **'Unread count error: {error}'**
  String unreadCountError(String error);

  /// refreshed
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshed;

  /// refreshedAll
  ///
  /// In en, this message translates to:
  /// **'Refreshed all'**
  String get refreshedAll;

  /// Shown after refreshing remote sources and syncing the account
  ///
  /// In en, this message translates to:
  /// **'Refreshed and synced'**
  String get refreshedAndSynced;

  /// add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// deleted
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// rssAtomUrl
  ///
  /// In en, this message translates to:
  /// **'RSS/Atom URL'**
  String get rssAtomUrl;

  /// feedOrWebsiteUrl
  ///
  /// In en, this message translates to:
  /// **'Feed / website URL'**
  String get feedOrWebsiteUrl;

  /// Helper text for the add subscription URL field
  ///
  /// In en, this message translates to:
  /// **'Paste a website or RSS URL'**
  String get feedOrWebsiteUrlHint;

  /// Button label for discovering RSS/Atom feeds from a URL
  ///
  /// In en, this message translates to:
  /// **'Find feeds'**
  String get findFeeds;

  /// discoveringFeeds
  ///
  /// In en, this message translates to:
  /// **'Discovering feeds...'**
  String get discoveringFeeds;

  /// addingSubscription
  ///
  /// In en, this message translates to:
  /// **'Adding subscription...'**
  String get addingSubscription;

  /// selectFeed
  ///
  /// In en, this message translates to:
  /// **'Select a feed'**
  String get selectFeed;

  /// noFeedsFound
  ///
  /// In en, this message translates to:
  /// **'No feeds found'**
  String get noFeedsFound;

  /// Inline hint shown when feed discovery finds no candidates
  ///
  /// In en, this message translates to:
  /// **'Paste the RSS/Atom URL directly or try another page from the site.'**
  String get noFeedsFoundHint;

  /// Section title for the selected subscription source preview
  ///
  /// In en, this message translates to:
  /// **'Source preview'**
  String get subscriptionPreview;

  /// Section title for discovered subscription result rows
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 subscription source} other{Found {count} subscription sources}}'**
  String subscriptionResultsFound(int count);

  /// Placeholder text when a discovered feed has no preview items
  ///
  /// In en, this message translates to:
  /// **'No recent preview items available'**
  String get subscriptionPreviewUnavailable;

  /// Label for a feed discovered because the input URL is itself a feed
  ///
  /// In en, this message translates to:
  /// **'RSS/Atom URL'**
  String get feedSourceDirect;

  /// Label for a feed discovered from HTML alternate/feed links
  ///
  /// In en, this message translates to:
  /// **'Discovered on page'**
  String get feedSourceAlternate;

  /// Label for a feed discovered by probing common RSS paths
  ///
  /// In en, this message translates to:
  /// **'Common feed path'**
  String get feedSourceCommonPath;

  /// name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// addedAndSynced
  ///
  /// In en, this message translates to:
  /// **'Added & synced'**
  String get addedAndSynced;

  /// Success panel title after adding a subscription
  ///
  /// In en, this message translates to:
  /// **'Subscription added'**
  String get subscriptionAddedTitle;

  /// Success panel message after adding a subscription
  ///
  /// In en, this message translates to:
  /// **'The subscription was added. You can open it now or keep adding more.'**
  String get subscriptionAddedMessage;

  /// Warning shown when adding a subscription succeeds but the initial refresh fails
  ///
  /// In en, this message translates to:
  /// **'The subscription was added, but the first refresh failed. You can retry refresh later.'**
  String get subscriptionRefreshWarning;

  /// Panel title when the feed already exists
  ///
  /// In en, this message translates to:
  /// **'Already subscribed'**
  String get subscriptionAlreadyExistsTitle;

  /// Panel message when the feed already exists
  ///
  /// In en, this message translates to:
  /// **'This feed is already in your subscriptions. No category changes were made.'**
  String get subscriptionAlreadyExistsMessage;

  /// Button label for opening a newly added or existing subscription
  ///
  /// In en, this message translates to:
  /// **'View subscription'**
  String get viewSubscription;

  /// Button label for resetting the add subscription form
  ///
  /// In en, this message translates to:
  /// **'Continue adding'**
  String get continueAddingSubscription;

  /// Button label for moving an existing subscription into the category from which add subscription was opened
  ///
  /// In en, this message translates to:
  /// **'Move to current category'**
  String get moveToCurrentCategory;

  /// deleteSubscription
  ///
  /// In en, this message translates to:
  /// **'Delete subscription'**
  String get deleteSubscription;

  /// deleteSubscriptionConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Delete subscription?'**
  String get deleteSubscriptionConfirmTitle;

  /// deleteSubscriptionConfirmContent
  ///
  /// In en, this message translates to:
  /// **'This will delete its cached articles too.'**
  String get deleteSubscriptionConfirmContent;

  /// makeAvailableOffline
  ///
  /// In en, this message translates to:
  /// **'Make available offline'**
  String get makeAvailableOffline;

  /// deleteCategory
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// deleteCategoryConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get deleteCategoryConfirmTitle;

  /// deleteCategoryConfirmContent
  ///
  /// In en, this message translates to:
  /// **'Feeds in this category will be moved to Uncategorized.'**
  String get deleteCategoryConfirmContent;

  /// Confirmation text for deleting a remote-backed category.
  ///
  /// In en, this message translates to:
  /// **'Delete this category on the remote service and then reconcile the local mirror.'**
  String get remoteDeleteCategoryConfirmContent;

  /// Title for writable remote taxonomy/category semantics.
  ///
  /// In en, this message translates to:
  /// **'Remote categories'**
  String get remoteWritableTaxonomyTitle;

  /// Description for writable remote taxonomy/category semantics.
  ///
  /// In en, this message translates to:
  /// **'Category changes are applied on the remote service and then mirrored locally.'**
  String get remoteWritableTaxonomyDescription;

  /// Title for read-only remote taxonomy/group mirror semantics.
  ///
  /// In en, this message translates to:
  /// **'Read-only remote groups'**
  String get remoteReadOnlyTaxonomyTitle;

  /// Description for read-only remote taxonomy/group mirror semantics.
  ///
  /// In en, this message translates to:
  /// **'These categories mirror read-only remote groups. Rename, delete, or move items in the remote service.'**
  String get remoteReadOnlyTaxonomyDescription;

  /// Title for a feed whose category assignment is managed by a read-only remote taxonomy mirror.
  ///
  /// In en, this message translates to:
  /// **'Category managed remotely'**
  String get feedCategoryReadOnlyTaxonomyTitle;

  /// Description for a feed whose category assignment is managed by a read-only remote taxonomy mirror.
  ///
  /// In en, this message translates to:
  /// **'This feed\'s category comes from a read-only remote group mirror.'**
  String get feedCategoryReadOnlyTaxonomyDescription;

  /// deleteTagConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Delete tag?'**
  String get deleteTagConfirmTitle;

  /// deleteTagConfirmContent
  ///
  /// In en, this message translates to:
  /// **'This will remove it from all articles.'**
  String get deleteTagConfirmContent;

  /// categoryDeleted
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeleted;

  /// refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// moveToCategory
  ///
  /// In en, this message translates to:
  /// **'Move to category'**
  String get moveToCategory;

  /// noFeedsFoundInOpml
  ///
  /// In en, this message translates to:
  /// **'No feeds found in OPML'**
  String get noFeedsFoundInOpml;

  /// importedFeeds
  ///
  /// In en, this message translates to:
  /// **'Imported {count} feeds'**
  String importedFeeds(int count);

  /// exportedOpml
  ///
  /// In en, this message translates to:
  /// **'Exported OPML'**
  String get exportedOpml;

  /// fullTextFailed
  ///
  /// In en, this message translates to:
  /// **'Full text failed: {error}'**
  String fullTextFailed(String error);

  /// scrollToLoadMore
  ///
  /// In en, this message translates to:
  /// **'Scroll to load more'**
  String get scrollToLoadMore;

  /// noArticles
  ///
  /// In en, this message translates to:
  /// **'No articles'**
  String get noArticles;

  /// Empty state message for the starred articles view
  ///
  /// In en, this message translates to:
  /// **'No starred articles yet'**
  String get noStarredArticles;

  /// Empty state message for the read-later articles view
  ///
  /// In en, this message translates to:
  /// **'No read-later articles yet'**
  String get noReadLaterArticles;

  /// noUnreadArticles
  ///
  /// In en, this message translates to:
  /// **'No unread articles'**
  String get noUnreadArticles;

  /// Article list empty state helper text when there are no articles
  ///
  /// In en, this message translates to:
  /// **'Add a subscription or refresh sources, and articles will appear here.'**
  String get articleListEmptySubtitle;

  /// Article list empty state helper text when the unread filter has no results
  ///
  /// In en, this message translates to:
  /// **'Everything in the current scope has been read.'**
  String get unreadEmptySubtitle;

  /// Saved section empty state helper text when searching saved articles has no results
  ///
  /// In en, this message translates to:
  /// **'No saved articles match this search.'**
  String get savedSearchEmptySubtitle;

  /// star
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get star;

  /// unstar
  ///
  /// In en, this message translates to:
  /// **'Unstar'**
  String get unstar;

  /// starred
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get starred;

  /// readLater
  ///
  /// In en, this message translates to:
  /// **'Read Later'**
  String get readLater;

  /// Action label for removing an article from the read-later list
  ///
  /// In en, this message translates to:
  /// **'Remove from Read Later'**
  String get removeReadLater;

  /// Action label for opening an article from a list
  ///
  /// In en, this message translates to:
  /// **'Open article'**
  String get openArticle;

  /// markRead
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get markRead;

  /// markUnread
  ///
  /// In en, this message translates to:
  /// **'Mark unread'**
  String get markUnread;

  /// collapse
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// expand
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// openInBrowser
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// copyLink
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// copiedToClipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// autoMarkRead
  ///
  /// In en, this message translates to:
  /// **'Auto-mark as read when opened'**
  String get autoMarkRead;

  /// search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// searchInContent
  ///
  /// In en, this message translates to:
  /// **'Search in content'**
  String get searchInContent;

  /// Action label for clearing article search text
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Search page empty state title before the user enters a query
  ///
  /// In en, this message translates to:
  /// **'Start searching'**
  String get searchStartTitle;

  /// Search page empty state helper text before the user enters a query
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search titles, summaries, and content.'**
  String get searchStartSubtitle;

  /// Search page empty state helper text when a query has no results
  ///
  /// In en, this message translates to:
  /// **'No articles match “{query}”.'**
  String searchNoResultsSubtitle(Object query);

  /// Reader helper text when an article id cannot be found
  ///
  /// In en, this message translates to:
  /// **'This article may have been deleted or is no longer available locally.'**
  String get articleNotFoundSubtitle;

  /// findInPage
  ///
  /// In en, this message translates to:
  /// **'Find in page'**
  String get findInPage;

  /// previousMatch
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get previousMatch;

  /// nextMatch
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// caseSensitive
  ///
  /// In en, this message translates to:
  /// **'Case sensitive'**
  String get caseSensitive;

  /// close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// groupingAndSorting
  ///
  /// In en, this message translates to:
  /// **'Grouping & Sorting'**
  String get groupingAndSorting;

  /// groupBy
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// groupNone
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get groupNone;

  /// groupByDay
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get groupByDay;

  /// sortOrder
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get sortOrder;

  /// sortNewestFirst
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewestFirst;

  /// sortOldestFirst
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldestFirst;

  /// enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// nameAlreadyExists
  ///
  /// In en, this message translates to:
  /// **'Name already exists'**
  String get nameAlreadyExists;

  /// lastChecked
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get lastChecked;

  /// lastSynced
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get lastSynced;

  /// never
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// cleanupReadArticles
  ///
  /// In en, this message translates to:
  /// **'Cleanup read articles'**
  String get cleanupReadArticles;

  /// cleanupNow
  ///
  /// In en, this message translates to:
  /// **'Run cleanup'**
  String get cleanupNow;

  /// No description provided for @cachingArticles.
  ///
  /// In en, this message translates to:
  /// **'Caching {count} articles...'**
  String cachingArticles(int count);

  /// manageTags
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// newTag
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get newTag;

  /// tagColor
  ///
  /// In en, this message translates to:
  /// **'Tag color'**
  String get tagColor;

  /// autoColor
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoColor;

  /// Error message displayed when tags fail to load in the dialog
  ///
  /// In en, this message translates to:
  /// **'Error loading tags'**
  String get tagsLoadingError;

  /// cleanedArticles
  ///
  /// In en, this message translates to:
  /// **'Cleaned {count} articles'**
  String cleanedArticles(int count);

  /// days
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String days(int days);

  /// services
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Action label for adding or registering an account
  ///
  /// In en, this message translates to:
  /// **'Add or register account'**
  String get addOrRegisterAccount;

  /// local
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// miniflux
  ///
  /// In en, this message translates to:
  /// **'Miniflux'**
  String get miniflux;

  /// fever
  ///
  /// In en, this message translates to:
  /// **'Fever'**
  String get fever;

  /// addLocal
  ///
  /// In en, this message translates to:
  /// **'Add Local'**
  String get addLocal;

  /// addLocalAccount
  ///
  /// In en, this message translates to:
  /// **'Add Local Account'**
  String get addLocalAccount;

  /// addMiniflux
  ///
  /// In en, this message translates to:
  /// **'Add Miniflux'**
  String get addMiniflux;

  /// addFever
  ///
  /// In en, this message translates to:
  /// **'Add Fever'**
  String get addFever;

  /// minifluxStrategy
  ///
  /// In en, this message translates to:
  /// **'Miniflux strategy'**
  String get minifluxStrategy;

  /// minifluxStrategySubtitle
  ///
  /// In en, this message translates to:
  /// **'Controls how much data is fetched/prefetched during sync.'**
  String get minifluxStrategySubtitle;

  /// remoteSyncStrategy
  ///
  /// In en, this message translates to:
  /// **'Remote sync strategy'**
  String get remoteSyncStrategy;

  /// remoteSyncStrategySubtitle
  ///
  /// In en, this message translates to:
  /// **'Controls the remote article window pulled during sync.'**
  String get remoteSyncStrategySubtitle;

  /// remoteSyncStrategyMinifluxSubtitle
  ///
  /// In en, this message translates to:
  /// **'Miniflux can page through remote entries up to this per-sync window.'**
  String get remoteSyncStrategyMinifluxSubtitle;

  /// remoteSyncStrategyFeverSubtitle
  ///
  /// In en, this message translates to:
  /// **'Fever syncs unread and saved items, capped by this per-sync window.'**
  String get remoteSyncStrategyFeverSubtitle;

  /// remoteEntriesLimit
  ///
  /// In en, this message translates to:
  /// **'Entries per sync'**
  String get remoteEntriesLimit;

  /// remoteFetchConcurrency
  ///
  /// In en, this message translates to:
  /// **'Remote fetch concurrency'**
  String get remoteFetchConcurrency;

  /// remoteFetchConcurrencySubtitle
  ///
  /// In en, this message translates to:
  /// **'Controls concurrent remote article batch requests during account sync.'**
  String get remoteFetchConcurrencySubtitle;

  /// minifluxWebFetchMode
  ///
  /// In en, this message translates to:
  /// **'Web page fetching'**
  String get minifluxWebFetchMode;

  /// minifluxWebFetchModeSubtitle
  ///
  /// In en, this message translates to:
  /// **'When \"Download Web Pages during Sync\" is enabled.'**
  String get minifluxWebFetchModeSubtitle;

  /// minifluxWebFetchModeClient
  ///
  /// In en, this message translates to:
  /// **'Client (Readability)'**
  String get minifluxWebFetchModeClient;

  /// minifluxWebFetchModeServer
  ///
  /// In en, this message translates to:
  /// **'Server (Miniflux fetch-content)'**
  String get minifluxWebFetchModeServer;

  /// unlimited
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// fieldName
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// Validation message shown when the name field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// baseUrl
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// Validation message shown when the base URL field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter base URL'**
  String get baseUrlRequired;

  /// minifluxBaseUrlHint
  ///
  /// In en, this message translates to:
  /// **'https://miniflux.example.com'**
  String get minifluxBaseUrlHint;

  /// feverBaseUrlHint
  ///
  /// In en, this message translates to:
  /// **'https://example.com/fever/'**
  String get feverBaseUrlHint;

  /// apiToken
  ///
  /// In en, this message translates to:
  /// **'API Token'**
  String get apiToken;

  /// Validation message shown when the API token field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter API token'**
  String get apiTokenRequired;

  /// apiKey
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// Label for App ID fields
  ///
  /// In en, this message translates to:
  /// **'App ID'**
  String get appId;

  /// Label for App Key fields
  ///
  /// In en, this message translates to:
  /// **'App Key'**
  String get appKey;

  /// Validation message shown when the API key field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter API key'**
  String get apiKeyRequired;

  /// authenticationMethod
  ///
  /// In en, this message translates to:
  /// **'Authentication method'**
  String get authenticationMethod;

  /// usernamePassword
  ///
  /// In en, this message translates to:
  /// **'Username & password'**
  String get usernamePassword;

  /// minifluxAuthHint
  ///
  /// In en, this message translates to:
  /// **'Use an API token (recommended) or username/password.'**
  String get minifluxAuthHint;

  /// feverAuthHint
  ///
  /// In en, this message translates to:
  /// **'Use an API key (recommended) or username/password.'**
  String get feverAuthHint;

  /// username
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Validation message shown when the username field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get usernameRequired;

  /// password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Validation message shown when the password field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get passwordRequired;

  /// Label for the default model field in the AI service editor
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get defaultModel;

  /// Helper text explaining that an empty API key field clears the saved value
  ///
  /// In en, this message translates to:
  /// **'Leave blank to clear the saved API key.'**
  String get savedApiKeyClearHint;

  /// Helper text explaining that empty credential fields clear the saved values
  ///
  /// In en, this message translates to:
  /// **'Leave blank to clear the saved credentials.'**
  String get savedCredentialsClearHint;

  /// Empty state shown when no custom AI services have been configured
  ///
  /// In en, this message translates to:
  /// **'No AI services added yet.'**
  String get aiServicesEmptyState;

  /// Summary text showing the configured model for an AI service
  ///
  /// In en, this message translates to:
  /// **'Model: {model}'**
  String modelSummary(String model);

  /// show
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// hide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// missingRequiredFields
  ///
  /// In en, this message translates to:
  /// **'Missing required fields'**
  String get missingRequiredFields;

  /// invalidBaseUrl
  ///
  /// In en, this message translates to:
  /// **'Invalid base URL'**
  String get invalidBaseUrl;

  /// onlySupportedInLocalAccount
  ///
  /// In en, this message translates to:
  /// **'Only supported in Local account'**
  String get onlySupportedInLocalAccount;

  /// autoRefresh
  ///
  /// In en, this message translates to:
  /// **'Auto source refresh'**
  String get autoRefresh;

  /// autoRefreshSubtitle
  ///
  /// In en, this message translates to:
  /// **'Refresh subscription sources at the selected interval. Mobile background refresh is system scheduled, usually no more often than every 15 minutes, and may not run exactly on time.'**
  String get autoRefreshSubtitle;

  /// off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// everyMinutes
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} min'**
  String everyMinutes(int minutes);

  /// appPreferences
  ///
  /// In en, this message translates to:
  /// **'App Preferences'**
  String get appPreferences;

  /// about
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// dataDirectory
  ///
  /// In en, this message translates to:
  /// **'Data directory'**
  String get dataDirectory;

  /// copyPath
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// openFolder
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// logDirectory
  ///
  /// In en, this message translates to:
  /// **'Log directory'**
  String get logDirectory;

  /// openLog
  ///
  /// In en, this message translates to:
  /// **'Open log'**
  String get openLog;

  /// openLogFolder
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get openLogFolder;

  /// exportLogs
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get exportLogs;

  /// exportedLogs
  ///
  /// In en, this message translates to:
  /// **'Logs exported'**
  String get exportedLogs;

  /// noLogsFound
  ///
  /// In en, this message translates to:
  /// **'No log files found'**
  String get noLogsFound;

  /// keyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// buildNumber
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get buildNumber;

  /// openSourceLicense
  ///
  /// In en, this message translates to:
  /// **'Open source license'**
  String get openSourceLicense;

  /// viewLicense
  ///
  /// In en, this message translates to:
  /// **'View license'**
  String get viewLicense;

  /// thirdPartyLicenses
  ///
  /// In en, this message translates to:
  /// **'Third-party licenses'**
  String get thirdPartyLicenses;

  /// viewThirdPartyLicenses
  ///
  /// In en, this message translates to:
  /// **'View all open source licenses'**
  String get viewThirdPartyLicenses;

  /// Error shown when the app fails to load the bundled license text
  ///
  /// In en, this message translates to:
  /// **'Failed to load license.'**
  String get licenseLoadFailed;

  /// Name of the app's primary license
  ///
  /// In en, this message translates to:
  /// **'MIT License'**
  String get mitLicenseName;

  /// Keyboard shortcut help text for moving to the next or previous article
  ///
  /// In en, this message translates to:
  /// **'J / K: Next / previous article'**
  String get shortcutNextPreviousArticle;

  /// Keyboard shortcut help text for refreshing the current selection
  ///
  /// In en, this message translates to:
  /// **'R: Refresh (current selection)'**
  String get shortcutRefreshCurrentSelection;

  /// Keyboard shortcut help text for toggling the unread-only filter
  ///
  /// In en, this message translates to:
  /// **'U: Toggle unread-only'**
  String get shortcutToggleUnreadOnly;

  /// Keyboard shortcut help text for toggling read/unread on the selected article
  ///
  /// In en, this message translates to:
  /// **'M: Toggle read/unread for selected article'**
  String get shortcutToggleReadUnreadSelectedArticle;

  /// Keyboard shortcut help text for toggling the star state on the selected article
  ///
  /// In en, this message translates to:
  /// **'S: Toggle star for selected article'**
  String get shortcutToggleStarSelectedArticle;

  /// Keyboard shortcut help text for searching articles or focusing find-in-page
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Cmd+F: Search articles (list); focus Find in page (reader)'**
  String get shortcutSearchArticlesAndFindInPage;

  /// filter
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// filterKeywordsHint
  ///
  /// In en, this message translates to:
  /// **'Add reserved keywords (separate with \";\", connect multiple with \"+\")'**
  String get filterKeywordsHint;

  /// sync
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// enableSync
  ///
  /// In en, this message translates to:
  /// **'Enable Sync'**
  String get enableSync;

  /// enableFilter
  ///
  /// In en, this message translates to:
  /// **'Enable Filter'**
  String get enableFilter;

  /// syncAlwaysEnabled
  ///
  /// In en, this message translates to:
  /// **'Always enabled (Settings - Sync - Sync Mode is \"All\")'**
  String get syncAlwaysEnabled;

  /// syncImages
  ///
  /// In en, this message translates to:
  /// **'Download Images during Sync'**
  String get syncImages;

  /// syncWebPages
  ///
  /// In en, this message translates to:
  /// **'Download Web Pages during Sync'**
  String get syncWebPages;

  /// Sync status: syncing (generic)
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncStatusSyncing;

  /// Sync status: syncing feeds
  ///
  /// In en, this message translates to:
  /// **'Syncing feeds'**
  String get syncStatusSyncingFeeds;

  /// Sync status: syncing subscriptions
  ///
  /// In en, this message translates to:
  /// **'Syncing subscriptions'**
  String get syncStatusSyncingSubscriptions;

  /// Sync status: syncing unread articles
  ///
  /// In en, this message translates to:
  /// **'Syncing unread articles'**
  String get syncStatusSyncingUnreadArticles;

  /// Sync status: uploading local/outbox changes
  ///
  /// In en, this message translates to:
  /// **'Uploading changes'**
  String get syncStatusUploadingChanges;

  /// Sync status: completed
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncStatusCompleted;

  /// Sync status: failed
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncStatusFailed;

  /// showAiSummary
  ///
  /// In en, this message translates to:
  /// **'Show Summary'**
  String get showAiSummary;

  /// summary
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// showImageTitle
  ///
  /// In en, this message translates to:
  /// **'Show Image Title'**
  String get showImageTitle;

  /// showAttachedImage
  ///
  /// In en, this message translates to:
  /// **'Show Attached Image'**
  String get showAttachedImage;

  /// htmlDecoding
  ///
  /// In en, this message translates to:
  /// **'HTML Decoding'**
  String get htmlDecoding;

  /// mobilizer
  ///
  /// In en, this message translates to:
  /// **'Mobilizer'**
  String get mobilizer;

  /// inherit
  ///
  /// In en, this message translates to:
  /// **'Inherit'**
  String get inherit;

  /// auto
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// autoOn
  ///
  /// In en, this message translates to:
  /// **'Auto (On)'**
  String get autoOn;

  /// autoOff
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get autoOff;

  /// defaultValue
  ///
  /// In en, this message translates to:
  /// **'Default Value'**
  String get defaultValue;

  /// Generic 'Default' option label
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultOption;

  /// userAgent
  ///
  /// In en, this message translates to:
  /// **'User-Agent'**
  String get userAgent;

  /// rssUserAgent
  ///
  /// In en, this message translates to:
  /// **'RSS/Atom User-Agent'**
  String get rssUserAgent;

  /// webUserAgent
  ///
  /// In en, this message translates to:
  /// **'Web Page User-Agent'**
  String get webUserAgent;

  /// userAgentRssHint
  ///
  /// In en, this message translates to:
  /// **'Used when fetching RSS/Atom feeds.'**
  String get userAgentRssHint;

  /// userAgentWebHint
  ///
  /// In en, this message translates to:
  /// **'Used when fetching full web pages (Readability).'**
  String get userAgentWebHint;

  /// resetToDefault
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// Notification title when exactly one new article is found
  ///
  /// In en, this message translates to:
  /// **'New Article'**
  String get notificationNewArticleTitle;

  /// Notification title when multiple new articles are found
  ///
  /// In en, this message translates to:
  /// **'New Articles'**
  String get notificationNewArticlesTitle;

  /// Notification body when multiple new articles are found
  ///
  /// In en, this message translates to:
  /// **'Found {count} new articles'**
  String notificationNewArticlesBody(int count);

  /// Android notification channel name for new articles
  ///
  /// In en, this message translates to:
  /// **'New Articles'**
  String get notificationNewArticlesChannelName;

  /// Android notification channel description for new articles
  ///
  /// In en, this message translates to:
  /// **'Notifications for new articles found during sync'**
  String get notificationNewArticlesChannelDescription;

  /// Tooltip for the window minimize button on desktop
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// Tooltip for the window maximize button on desktop
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// Tooltip for the window restore button on desktop
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// Tooltip for the window close button on desktop
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// Settings tab for translation and AI services
  ///
  /// In en, this message translates to:
  /// **'Translation & AI'**
  String get translationAndAiServices;

  /// Translation section title
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// Setting title for selecting translation provider
  ///
  /// In en, this message translates to:
  /// **'Translation provider'**
  String get translationProvider;

  /// AI services section title
  ///
  /// In en, this message translates to:
  /// **'AI services'**
  String get aiServices;

  /// Button/title for adding an AI service
  ///
  /// In en, this message translates to:
  /// **'Add AI service'**
  String get addAiService;

  /// Generic label for AI service
  ///
  /// In en, this message translates to:
  /// **'AI service'**
  String get aiService;

  /// AI summary section title/label
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get aiSummary;

  /// Setting title for selecting AI summary service
  ///
  /// In en, this message translates to:
  /// **'AI summary service'**
  String get aiSummaryService;

  /// Setting title for selecting target language
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get targetLanguage;

  /// Option label for following the app language
  ///
  /// In en, this message translates to:
  /// **'Follow app language'**
  String get followAppLanguage;

  /// Display label for the Google web translation provider
  ///
  /// In en, this message translates to:
  /// **'Google Translate (web)'**
  String get translationProviderGoogleWeb;

  /// Display label for the Bing web translation provider
  ///
  /// In en, this message translates to:
  /// **'Bing Translate (web)'**
  String get translationProviderBingWeb;

  /// Display label for the Baidu API translation provider
  ///
  /// In en, this message translates to:
  /// **'Baidu Translate (API)'**
  String get translationProviderBaiduApi;

  /// Display label for the DeepL API translation provider
  ///
  /// In en, this message translates to:
  /// **'DeepL (API)'**
  String get translationProviderDeepLApi;

  /// Display label for the DeepLX translation provider
  ///
  /// In en, this message translates to:
  /// **'DeepLX'**
  String get translationProviderDeepLX;

  /// Display label for an AI-backed translation provider
  ///
  /// In en, this message translates to:
  /// **'AI: {name}'**
  String translationProviderAiService(Object name);

  /// Subtitle for configuring Baidu translation credentials
  ///
  /// In en, this message translates to:
  /// **'Configure App ID / App Key'**
  String get translationProviderBaiduApiSubtitle;

  /// Dialog title for editing the DeepLX base URL
  ///
  /// In en, this message translates to:
  /// **'DeepLX Base URL'**
  String get deepLXBaseUrlTitle;

  /// Label for the DeepL endpoint selection
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get deepLEndpoint;

  /// Label for the DeepL free endpoint
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get deepLEndpointFree;

  /// Label for the DeepL pro endpoint
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get deepLEndpointPro;

  /// Menu action for making an AI service the default one
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// Menu label shown when an AI service is already the default one
  ///
  /// In en, this message translates to:
  /// **'Default (already set)'**
  String get defaultAlreadySet;

  /// Setting title for AI summary prompt template
  ///
  /// In en, this message translates to:
  /// **'AI summary prompt'**
  String get aiSummaryPrompt;

  /// Setting title for AI translation prompt template
  ///
  /// In en, this message translates to:
  /// **'AI translation prompt'**
  String get aiTranslationPrompt;

  /// Default AI summary prompt template
  ///
  /// In en, this message translates to:
  /// **'Please summarize this article in {language} (title: {title}): {content}'**
  String defaultAiSummaryPromptTemplate(
    Object language,
    Object title,
    Object content,
  );

  /// Default AI translation prompt template (only used for AI translation)
  ///
  /// In en, this message translates to:
  /// **'Please translate this article fragment into {language} (title: {title}): {content}'**
  String defaultAiTranslationPromptTemplate(
    Object language,
    Object title,
    Object content,
  );

  /// Header for listing available prompt template variables
  ///
  /// In en, this message translates to:
  /// **'Available variables'**
  String get promptVariables;

  /// Description text for {{content}} variable
  ///
  /// In en, this message translates to:
  /// **'Article content'**
  String get promptVariableContentDescription;

  /// Description text for {{language}} variable
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get promptVariableLanguageDescription;

  /// Description text for {{title}} variable
  ///
  /// In en, this message translates to:
  /// **'Article title'**
  String get promptVariableTitleDescription;

  /// Tokens per minute limit setting
  ///
  /// In en, this message translates to:
  /// **'TPM limit'**
  String get tpmLimit;

  /// Subtitle text explaining the TPM limit behavior
  ///
  /// In en, this message translates to:
  /// **'0 means unlimited; requests will be queued when exceeded.'**
  String get tpmLimitSubtitle;

  /// Action button label for generating AI summary
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get aiSummaryAction;

  /// Action button label for translating an article
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateAction;

  /// Title for selecting translation mode
  ///
  /// In en, this message translates to:
  /// **'Translation mode'**
  String get translationMode;

  /// Option label for immersive (bilingual) translation mode
  ///
  /// In en, this message translates to:
  /// **'Immersive translation'**
  String get immersiveTranslation;

  /// Option label for traditional (translated-only) translation mode
  ///
  /// In en, this message translates to:
  /// **'Traditional translation'**
  String get traditionalTranslation;

  /// Generic loading state text for generating AI/translation
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// Generic queued state text
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queued;

  /// Action label for regenerating AI/translation output
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// Hint shown when cached content is outdated due to prompt changes
  ///
  /// In en, this message translates to:
  /// **'Prompt updated; regenerate to refresh.'**
  String get cachedPromptOutdated;

  /// Banner text shown when article language differs from target language
  ///
  /// In en, this message translates to:
  /// **'Detected {source} content; target language is {target}.'**
  String languageMismatchBanner(Object source, Object target);

  /// Action label to disable language mismatch reminders for a source language
  ///
  /// In en, this message translates to:
  /// **'Don\'t remind for this language'**
  String get dontRemindThisLanguage;

  /// Setting title for auto AI summary
  ///
  /// In en, this message translates to:
  /// **'Auto AI summary'**
  String get autoAiSummary;

  /// Setting title for auto translation
  ///
  /// In en, this message translates to:
  /// **'Auto translate'**
  String get autoTranslate;

  /// Error message shown when no AI service is configured/enabled
  ///
  /// In en, this message translates to:
  /// **'AI service not configured.'**
  String get aiNotConfigured;

  /// Error message shown when the selected translation provider is not supported
  ///
  /// In en, this message translates to:
  /// **'Translation is not available for the selected provider.'**
  String get translationNotAvailable;

  /// Action label to clear/hide the translated view
  ///
  /// In en, this message translates to:
  /// **'Clear translation'**
  String get clearTranslation;

  /// Title for the database recovery dialog
  ///
  /// In en, this message translates to:
  /// **'Database recovery'**
  String get dbRecoveryTitle;

  /// Description text shown in the database recovery dialog
  ///
  /// In en, this message translates to:
  /// **'The app detected a database issue and performed recovery. Your data was preserved on disk (backup / moved file).'**
  String get dbRecoveryDescription;

  /// Label for the recovery time field
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get dbRecoveryTimeLabel;

  /// Label for the database name field
  ///
  /// In en, this message translates to:
  /// **'DB name'**
  String get dbRecoveryDbNameLabel;

  /// Label for the fallback database name field
  ///
  /// In en, this message translates to:
  /// **'Opened as'**
  String get dbRecoveryOpenedAsLabel;

  /// Label for the backup file path field
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get dbRecoveryBackupPathLabel;

  /// Label for the moved original db file path field
  ///
  /// In en, this message translates to:
  /// **'Moved original'**
  String get dbRecoveryMovedOriginalPathLabel;

  /// Label for the error message field
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get dbRecoveryErrorLabel;

  /// Hint shown at the bottom of the recovery dialog
  ///
  /// In en, this message translates to:
  /// **'Tip: Use the copy buttons to copy paths for troubleshooting or support.'**
  String get dbRecoveryDataPreservedHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
