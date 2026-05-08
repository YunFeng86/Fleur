import 'package:flutter/material.dart';

import '../network/user_agents.dart';
import '../../theme/seed_color_presets.dart';
import '../../utils/language_utils.dart';

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
    this.autoRefreshMinutes,
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
  });

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

  /// Auto-refresh interval in minutes. `null` means disabled.
  final int? autoRefreshMinutes;

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
      autoRefreshMinutes: autoRefreshMinutes == _unset
          ? this.autoRefreshMinutes
          : autoRefreshMinutes as int?,
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
    'autoRefreshMinutes': autoRefreshMinutes,
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
    final rawThemeMode = json['themeMode'];
    final mode = switch (rawThemeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final useDynamicColor = json['useDynamicColor'];
    final seedColorPreset = json['seedColorPreset'];
    final localeTag = json['localeTag'];

    final autoMarkRead = json['autoMarkRead'];
    final autoRefreshMinutes = json['autoRefreshMinutes'];
    final autoRefreshConcurrency = json['autoRefreshConcurrency'];
    final searchInContent = json['searchInContent'];
    final cleanupReadOlderThanDays = json['cleanupReadOlderThanDays'];

    // Global defaults
    final filterEnabled = json['filterEnabled'];
    final filterKeywords = json['filterKeywords'];
    final syncEnabled = json['syncEnabled'];
    final syncImages = json['syncImages'];
    final syncWebPages = json['syncWebPages'];
    final showAiSummary = json['showAiSummary'];
    final autoTranslate = json['autoTranslate'];
    final remoteEntriesLimit = json['remoteEntriesLimit'];
    final minifluxEntriesLimit = json['minifluxEntriesLimit'];
    final remoteFetchConcurrency = json['remoteFetchConcurrency'];
    final minifluxWebFetchMode = json['minifluxWebFetchMode'];
    final rssUserAgent = json['rssUserAgent'];
    final webUserAgent = json['webUserAgent'];

    ArticleGroupMode parseGroupMode(Object? v) {
      final s = v is String ? v : '';
      return switch (s) {
        'day' => ArticleGroupMode.day,
        _ => ArticleGroupMode.none,
      };
    }

    ArticleSortOrder parseSortOrder(Object? v) {
      final s = v is String ? v : '';
      return switch (s) {
        'oldestFirst' => ArticleSortOrder.oldestFirst,
        _ => ArticleSortOrder.newestFirst,
      };
    }

    SeedColorPreset parseSeedColorPreset(Object? v) {
      final s = v is String ? v : '';
      for (final p in SeedColorPreset.values) {
        if (p.name == s) return p;
      }
      return SeedColorPreset.blue;
    }

    MinifluxWebFetchMode parseMinifluxWebFetchMode(Object? v) {
      final s = v is String ? v : '';
      for (final m in MinifluxWebFetchMode.values) {
        if (m.name == s) return m;
      }
      return MinifluxWebFetchMode.clientReadability;
    }

    final loaded = AppSettings(
      themeMode: mode,
      useDynamicColor: useDynamicColor is! bool || useDynamicColor,
      seedColorPreset: parseSeedColorPreset(seedColorPreset),
      localeTag: localeTag is String && localeTag.trim().isNotEmpty
          ? localeTag
          : null,
      autoMarkRead: autoMarkRead is! bool || autoMarkRead,
      autoRefreshMinutes: autoRefreshMinutes is num
          ? autoRefreshMinutes.toInt()
          : null,
      autoRefreshConcurrency: autoRefreshConcurrency is num
          ? autoRefreshConcurrency.toInt()
          : 2,
      articleGroupMode: parseGroupMode(json['articleGroupMode']),
      articleSortOrder: parseSortOrder(json['articleSortOrder']),
      searchInContent: searchInContent is! bool || searchInContent,
      cleanupReadOlderThanDays: cleanupReadOlderThanDays is num
          ? cleanupReadOlderThanDays.toInt()
          : null,
      filterEnabled: filterEnabled is bool && filterEnabled,
      filterKeywords: filterKeywords is String ? filterKeywords : '',
      syncEnabled: syncEnabled is! bool || syncEnabled,
      syncImages: syncImages is! bool || syncImages,
      syncWebPages: syncWebPages is bool && syncWebPages,
      showAiSummary: showAiSummary is bool && showAiSummary,
      autoTranslate: autoTranslate is bool && autoTranslate,
      minifluxEntriesLimit: remoteEntriesLimit is num
          ? remoteEntriesLimit.toInt()
          : minifluxEntriesLimit is num
          ? minifluxEntriesLimit.toInt()
          : 400,
      remoteFetchConcurrency: remoteFetchConcurrency is num
          ? remoteFetchConcurrency.toInt()
          : 2,
      minifluxWebFetchMode: parseMinifluxWebFetchMode(minifluxWebFetchMode),
      rssUserAgent: rssUserAgent is String && rssUserAgent.trim().isNotEmpty
          ? rssUserAgent
          : UserAgents.rss,
      webUserAgent: webUserAgent is String && webUserAgent.trim().isNotEmpty
          ? webUserAgent
          : UserAgents.webForCurrentPlatform(),
    );
    return loaded.normalized();
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
      autoRefreshMinutes: autoRefreshMinutes,
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
