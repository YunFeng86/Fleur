import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings/app_settings.dart';
import '../services/settings/app_settings_store.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore();
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    return ref.read(appSettingsStoreProvider).load();
  }

  Future<void> save(AppSettings next) async {
    state = AsyncValue.data(next);
    await ref.read(appSettingsStoreProvider).save(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(themeMode: mode));
  }

  Future<void> setLocaleTag(String? localeTag) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(localeTag: localeTag));
  }

  Future<void> setAutoMarkRead(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(autoMarkRead: value));
  }

  Future<void> setAutoRefreshMinutes(int? minutes) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(autoRefreshMinutes: minutes));
  }

  Future<void> setAutoRefreshConcurrency(int concurrency) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(autoRefreshConcurrency: concurrency));
  }

  Future<void> setArticleGroupMode(ArticleGroupMode mode) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(articleGroupMode: mode));
  }

  Future<void> setArticleSortOrder(ArticleSortOrder order) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(articleSortOrder: order));
  }

  Future<void> setSearchInContent(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(searchInContent: value));
  }

  Future<void> setCleanupReadOlderThanDays(int? days) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(cleanupReadOlderThanDays: days));
  }

  Future<void> setFilterEnabled(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(filterEnabled: value));
  }

  Future<void> setFilterKeywords(String value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(filterKeywords: value));
  }

  Future<void> setSyncEnabled(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(syncEnabled: value));
  }

  Future<void> setSyncImages(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(syncImages: value));
  }

  Future<void> setSyncWebPages(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(syncWebPages: value));
  }

  Future<void> setShowAiSummary(bool value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(showAiSummary: value));
  }

  Future<void> setRssUserAgent(String value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(rssUserAgent: value));
  }

  Future<void> setWebUserAgent(String value) async {
    final cur = state.valueOrNull ?? const AppSettings();
    await save(cur.copyWith(webUserAgent: value));
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
