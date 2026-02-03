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
  /// **'Flutter Reader'**
  String get appTitle;

  /// notFound
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Global navigation label: dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

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
  /// **'Refresh all'**
  String get refreshAll;

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

  /// noUnreadArticles
  ///
  /// In en, this message translates to:
  /// **'No unread articles'**
  String get noUnreadArticles;

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

  /// autoRefresh
  ///
  /// In en, this message translates to:
  /// **'Auto refresh'**
  String get autoRefresh;

  /// autoRefreshSubtitle
  ///
  /// In en, this message translates to:
  /// **'Automatically refresh feeds in background'**
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

  /// keyboardShortcuts
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

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

  /// showAiSummary
  ///
  /// In en, this message translates to:
  /// **'Show AI Summary'**
  String get showAiSummary;

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
