import 'package:flutter/material.dart';

import '../network/user_agents.dart';

enum ArticleGroupMode { none, day }

enum ArticleSortOrder { newestFirst, oldestFirst }

class AppSettings {
  static const _Unset _unset = _Unset();

  const AppSettings({
    this.themeMode = ThemeMode.system,
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
    this.rssUserAgent = UserAgents.rss,
    this.webUserAgent = UserAgents.web,
  });

  final ThemeMode themeMode;
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

  /// User-Agent for RSS/Atom fetches.
  final String rssUserAgent;

  /// User-Agent for full web page (readability) fetches.
  final String webUserAgent;

  AppSettings copyWith({
    ThemeMode? themeMode,
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
    String? rssUserAgent,
    String? webUserAgent,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
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
      rssUserAgent: rssUserAgent ?? this.rssUserAgent,
      webUserAgent: webUserAgent ?? this.webUserAgent,
    );
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
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

    return AppSettings(
      themeMode: mode,
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
      rssUserAgent: rssUserAgent is String && rssUserAgent.trim().isNotEmpty
          ? rssUserAgent
          : UserAgents.rss,
      webUserAgent: webUserAgent is String && webUserAgent.trim().isNotEmpty
          ? webUserAgent
          : UserAgents.web,
    );
  }
}

class _Unset {
  const _Unset();
}
