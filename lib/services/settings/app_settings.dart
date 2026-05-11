import 'package:flutter/material.dart';

import '../network/user_agents.dart';
import '../../theme/seed_color_presets.dart';
import '../../utils/language_utils.dart';
import 'settings_json.dart';

enum ArticleGroupMode { none, day }

enum ArticleSortOrder { newestFirst, oldestFirst }

enum MinifluxWebFetchMode { clientReadability, serverFetchContent }

class AppSettings {
  static const _Unset _unset = _Unset();

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = true,
    this.seedColorPreset = SeedColorPreset.blue,
    this.localeTag,
    this.autoMarkRead = true,
    int? sourceRefreshMinutes,
    int? autoRefreshMinutes,
    this.autoRefreshConcurrency = 2,
    this.articleGroupMode = ArticleGroupMode.none,
    this.articleSortOrder = ArticleSortOrder.newestFirst,
    this.searchInContent = true,
    this.cleanupReadOlderThanDays,
    this.filterEnabled = false,
    this.filterKeywords = '',
    this.syncEnabled = true,
    this.syncImages = true,
    this.syncWebPages = false,
    this.showAiSummary = false,
    this.autoTranslate = false,
    this.minifluxEntriesLimit = 400,
    this.remoteFetchConcurrency = 2,
    this.minifluxWebFetchMode = MinifluxWebFetchMode.clientReadability,
    this.rssUserAgent = UserAgents.rss,
    // Keep legacy value as a const fallback; prefer [AppSettings.defaults].
    this.webUserAgent = UserAgents.web,
  }) : sourceRefreshMinutes =
           sourceRefreshMinutes ??
           (autoRefreshMinutes == null
               ? null
               : autoRefreshMinutes <= 0
               ? null
               : autoRefreshMinutes < 15
               ? 15
               : autoRefreshMinutes);

  static AppSettings defaults() {
    return AppSettings(
      rssUserAgent: UserAgents.rss,
      webUserAgent: UserAgents.webForCurrentPlatform(),
    );
  }

  final ThemeMode themeMode;

  /// Whether to use Material You dynamic colors when available (Android 12+).
  ///
  /// When unsupported, the app falls back to the seeded color scheme.
  final bool useDynamicColor;

  /// Seed color preset used for generating the ColorScheme when dynamic colors
  /// are unavailable/disabled.
  final SeedColorPreset seedColorPreset;
  // null => follow system language.
  final String? localeTag;

  /// Whether to auto-mark articles as read when opened in the reader.
  final bool autoMarkRead;

  /// Source refresh interval in minutes. `null` means disabled.
  final int? sourceRefreshMinutes;

  /// Legacy alias for source refresh interval.
  @Deprecated('Use sourceRefreshMinutes instead.')
  int? get autoRefreshMinutes => sourceRefreshMinutes;

  /// Number of concurrent feeds to refresh at once.
  final int autoRefreshConcurrency;

  /// How the article list should be grouped (view-only; does not change data).
  final ArticleGroupMode articleGroupMode;

  /// Article list sorting order.
  final ArticleSortOrder articleSortOrder;

  /// Whether search should include article content/full text in addition to
  /// title/author/link.
  final bool searchInContent;

  /// If set, allows manual cleanup of read & unstarred articles older than N days.
  /// `null` means disabled.
  final int? cleanupReadOlderThanDays;

  // --- Global Defaults ---
  final bool filterEnabled;
  final String filterKeywords;
  final bool syncEnabled;
  final bool syncImages;
  final bool syncWebPages;
  final bool showAiSummary;
  final bool autoTranslate;

  // --- Remote Service Strategy ---
  /// Max number of entries to pull per sync call.
  ///
  /// 0 means "unlimited" (paginate until server has no more).
  final int minifluxEntriesLimit;

  int get remoteEntriesLimit => minifluxEntriesLimit;

  /// Number of concurrent remote article batch requests during account sync.
  final int remoteFetchConcurrency;

  /// How to fetch full web content for Miniflux entries when "syncWebPages" is
  /// enabled.
  final MinifluxWebFetchMode minifluxWebFetchMode;

  /// User-Agent for RSS/Atom fetches.
  final String rssUserAgent;

  /// User-Agent for full web page (readability) fetches.
  final String webUserAgent;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    SeedColorPreset? seedColorPreset,
    Object? localeTag = _unset,
    bool? autoMarkRead,
    Object? sourceRefreshMinutes = _unset,
    Object? autoRefreshMinutes = _unset,
    int? autoRefreshConcurrency,
    ArticleGroupMode? articleGroupMode,
    ArticleSortOrder? articleSortOrder,
    bool? searchInContent,
    Object? cleanupReadOlderThanDays = _unset,
    bool? filterEnabled,
    String? filterKeywords,
    bool? syncEnabled,
    bool? syncImages,
    bool? syncWebPages,
    bool? showAiSummary,
    bool? autoTranslate,
    int? remoteEntriesLimit,
    int? minifluxEntriesLimit,
    int? remoteFetchConcurrency,
    MinifluxWebFetchMode? minifluxWebFetchMode,
    String? rssUserAgent,
    String? webUserAgent,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      seedColorPreset: seedColorPreset ?? this.seedColorPreset,
      localeTag: localeTag == _unset ? this.localeTag : localeTag as String?,
      autoMarkRead: autoMarkRead ?? this.autoMarkRead,
      sourceRefreshMinutes: sourceRefreshMinutes != _unset
          ? sourceRefreshMinutes as int?
          : autoRefreshMinutes != _unset
          ? _migrateLegacySourceRefreshMinutes(autoRefreshMinutes as int?)
          : this.sourceRefreshMinutes,
      autoRefreshConcurrency:
          autoRefreshConcurrency ?? this.autoRefreshConcurrency,
      articleGroupMode: articleGroupMode ?? this.articleGroupMode,
      articleSortOrder: articleSortOrder ?? this.articleSortOrder,
      searchInContent: searchInContent ?? this.searchInContent,
      cleanupReadOlderThanDays: cleanupReadOlderThanDays == _unset
          ? this.cleanupReadOlderThanDays
          : cleanupReadOlderThanDays as int?,
      filterEnabled: filterEnabled ?? this.filterEnabled,
      filterKeywords: filterKeywords ?? this.filterKeywords,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncImages: syncImages ?? this.syncImages,
      syncWebPages: syncWebPages ?? this.syncWebPages,
      showAiSummary: showAiSummary ?? this.showAiSummary,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      minifluxEntriesLimit:
          remoteEntriesLimit ??
          minifluxEntriesLimit ??
          this.minifluxEntriesLimit,
      remoteFetchConcurrency:
          remoteFetchConcurrency ?? this.remoteFetchConcurrency,
      minifluxWebFetchMode: minifluxWebFetchMode ?? this.minifluxWebFetchMode,
      rssUserAgent: rssUserAgent ?? this.rssUserAgent,
      webUserAgent: webUserAgent ?? this.webUserAgent,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'useDynamicColor': useDynamicColor,
    'seedColorPreset': seedColorPreset.name,
    'localeTag': localeTag,
    'autoMarkRead': autoMarkRead,
    'sourceRefreshMinutes': sourceRefreshMinutes,
    'autoRefreshConcurrency': autoRefreshConcurrency,
    'articleGroupMode': articleGroupMode.name,
    'articleSortOrder': articleSortOrder.name,
    'searchInContent': searchInContent,
    'cleanupReadOlderThanDays': cleanupReadOlderThanDays,
    'filterEnabled': filterEnabled,
    'filterKeywords': filterKeywords,
    'syncEnabled': syncEnabled,
    'syncImages': syncImages,
    'syncWebPages': syncWebPages,
    'showAiSummary': showAiSummary,
    'autoTranslate': autoTranslate,
    'minifluxEntriesLimit': minifluxEntriesLimit,
    'remoteFetchConcurrency': remoteFetchConcurrency,
    'minifluxWebFetchMode': minifluxWebFetchMode.name,
    'rssUserAgent': rssUserAgent,
    'webUserAgent': webUserAgent,
  };

  static AppSettings fromJson(Map<String, Object?> json) {
    final sourceRefreshMinutes = readOptionalInt(json['sourceRefreshMinutes']);
    final autoRefreshMinutes = readOptionalInt(json['autoRefreshMinutes']);
    final remoteEntriesLimit = readOptionalInt(json['remoteEntriesLimit']);
    final minifluxEntriesLimit = readOptionalInt(json['minifluxEntriesLimit']);
    final filterKeywords = json['filterKeywords'];

    final loaded = AppSettings(
      themeMode: readEnumByNameOr(
        ThemeMode.values,
        json['themeMode'],
        ThemeMode.system,
        trim: false,
      ),
      useDynamicColor: readBoolOr(json['useDynamicColor'], fallback: true),
      seedColorPreset: readEnumByNameOr(
        SeedColorPreset.values,
        json['seedColorPreset'],
        SeedColorPreset.blue,
        trim: false,
      ),
      localeTag: readOptionalString(json['localeTag']),
      autoMarkRead: readBoolOr(json['autoMarkRead'], fallback: true),
      sourceRefreshMinutes:
          sourceRefreshMinutes ??
          _migrateLegacySourceRefreshMinutes(autoRefreshMinutes),
      autoRefreshConcurrency: readIntOr(json['autoRefreshConcurrency'], 2),
      articleGroupMode: readEnumByNameOr(
        ArticleGroupMode.values,
        json['articleGroupMode'],
        ArticleGroupMode.none,
        trim: false,
      ),
      articleSortOrder: readEnumByNameOr(
        ArticleSortOrder.values,
        json['articleSortOrder'],
        ArticleSortOrder.newestFirst,
        trim: false,
      ),
      searchInContent: readBoolOr(json['searchInContent'], fallback: true),
      cleanupReadOlderThanDays: readOptionalInt(
        json['cleanupReadOlderThanDays'],
      ),
      filterEnabled: readBoolOr(json['filterEnabled'], fallback: false),
      filterKeywords: filterKeywords is String ? filterKeywords : '',
      syncEnabled: readBoolOr(json['syncEnabled'], fallback: true),
      syncImages: readBoolOr(json['syncImages'], fallback: true),
      syncWebPages: readBoolOr(json['syncWebPages'], fallback: false),
      showAiSummary: readBoolOr(json['showAiSummary'], fallback: false),
      autoTranslate: readBoolOr(json['autoTranslate'], fallback: false),
      minifluxEntriesLimit: remoteEntriesLimit ?? minifluxEntriesLimit ?? 400,
      remoteFetchConcurrency: readIntOr(json['remoteFetchConcurrency'], 2),
      minifluxWebFetchMode: readEnumByNameOr(
        MinifluxWebFetchMode.values,
        json['minifluxWebFetchMode'],
        MinifluxWebFetchMode.clientReadability,
        trim: false,
      ),
      rssUserAgent: readOptionalString(json['rssUserAgent']) ?? UserAgents.rss,
      webUserAgent:
          readOptionalString(json['webUserAgent']) ??
          UserAgents.webForCurrentPlatform(),
    );
    return loaded.normalized();
  }

  static int? _migrateLegacySourceRefreshMinutes(int? minutes) {
    if (minutes == null) return null;
    if (minutes <= 0) return null;
    return minutes < 15 ? 15 : minutes;
  }

  static int? _normalizeSourceRefreshMinutes(int? minutes) {
    if (minutes == null || minutes <= 0) return null;
    return minutes < 15 ? 15 : minutes;
  }

  AppSettings normalized() {
    final normalizedLocaleTag = (() {
      final raw = (localeTag ?? '').trim();
      if (raw.isEmpty) return null;
      final normalized = normalizeAppLocaleTag(raw);
      return normalized.isEmpty ? null : normalized;
    })();
    final normalizedRssUserAgent = rssUserAgent.trim().isEmpty
        ? UserAgents.rss
        : rssUserAgent.trim();
    final normalizedWebUserAgent = webUserAgent.trim().isEmpty
        ? UserAgents.webForCurrentPlatform()
        : webUserAgent.trim();
    final normalizedRemoteFetchConcurrency = remoteFetchConcurrency < 1
        ? 1
        : remoteFetchConcurrency > 4
        ? 4
        : remoteFetchConcurrency;

    return AppSettings(
      themeMode: themeMode,
      useDynamicColor: useDynamicColor,
      seedColorPreset: seedColorPreset,
      localeTag: normalizedLocaleTag,
      autoMarkRead: autoMarkRead,
      sourceRefreshMinutes: _normalizeSourceRefreshMinutes(
        sourceRefreshMinutes,
      ),
      autoRefreshConcurrency: autoRefreshConcurrency,
      articleGroupMode: articleGroupMode,
      articleSortOrder: articleSortOrder,
      searchInContent: searchInContent,
      cleanupReadOlderThanDays: cleanupReadOlderThanDays,
      filterEnabled: filterEnabled,
      filterKeywords: filterKeywords,
      syncEnabled: syncEnabled,
      syncImages: syncImages,
      syncWebPages: syncWebPages,
      showAiSummary: showAiSummary,
      autoTranslate: autoTranslate,
      minifluxEntriesLimit: minifluxEntriesLimit,
      remoteFetchConcurrency: normalizedRemoteFetchConcurrency,
      minifluxWebFetchMode: minifluxWebFetchMode,
      rssUserAgent: normalizedRssUserAgent,
      webUserAgent: normalizedWebUserAgent,
    );
  }
}

class _Unset {
  const _Unset();
}
