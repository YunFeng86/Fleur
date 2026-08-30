import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/app_logger.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/app_settings_store.dart';
import '../theme/seed_color_presets.dart';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore();
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final loaded = await ref.read(appSettingsStoreProvider).load();
    return loaded.normalized();
  }

  Future<void> save(AppSettings next) async {
    final normalized = next.normalized();
    state = AsyncValue.data(normalized);
    await ref.read(appSettingsStoreProvider).save(normalized);
  }

  /// Setter entry point: UI callbacks usually fire this without awaiting, so
  /// persist failures are logged and the optimistic in-memory state is kept
  /// instead of surfacing as an unhandled async exception.
  Future<void> _saveQuietly(AppSettings next) async {
    try {
      await save(next);
    } catch (e, s) {
      AppLogger.w(
        'Settings save failed; keeping in-memory state',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'store': 'AppSettingsStore',
          'operation': 'replace',
          'settingKey': 'appSettings',
        },
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(themeMode: mode));
  }

  Future<void> setUseDynamicColor(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(useDynamicColor: value));
  }

  Future<void> setSeedColorPreset(SeedColorPreset preset) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(seedColorPreset: preset));
  }

  Future<void> setLocaleTag(String? localeTag) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(localeTag: localeTag));
  }

  Future<void> setAutoMarkRead(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(autoMarkRead: value));
  }

  Future<void> setSourceRefreshMinutes(int? minutes) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(sourceRefreshMinutes: minutes));
  }

  @Deprecated('Use setSourceRefreshMinutes instead.')
  Future<void> setAutoRefreshMinutes(int? minutes) {
    return setSourceRefreshMinutes(minutes);
  }

  Future<void> setAutoRefreshConcurrency(int concurrency) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(autoRefreshConcurrency: concurrency));
  }

  Future<void> setArticleGroupMode(ArticleGroupMode mode) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(articleGroupMode: mode));
  }

  Future<void> setArticleSortOrder(ArticleSortOrder order) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(articleSortOrder: order));
  }

  Future<void> setSearchInContent(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(searchInContent: value));
  }

  Future<void> setCleanupReadOlderThanDays(int? days) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(cleanupReadOlderThanDays: days));
  }

  Future<void> setFilterEnabled(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(filterEnabled: value));
  }

  Future<void> setFilterKeywords(String value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(filterKeywords: value));
  }

  Future<void> setSyncEnabled(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(syncEnabled: value));
  }

  Future<void> setSyncImages(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(syncImages: value));
  }

  Future<void> setSyncWebPages(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(syncWebPages: value));
  }

  Future<void> setShowAiSummary(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(showAiSummary: value));
  }

  Future<void> setAutoTranslate(bool value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(autoTranslate: value));
  }

  Future<void> setRemoteEntriesLimit(int limit) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(remoteEntriesLimit: limit));
  }

  Future<void> setMinifluxEntriesLimit(int limit) async {
    await setRemoteEntriesLimit(limit);
  }

  Future<void> setRemoteFetchConcurrency(int concurrency) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(remoteFetchConcurrency: concurrency));
  }

  Future<void> setMinifluxWebFetchMode(MinifluxWebFetchMode mode) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(minifluxWebFetchMode: mode));
  }

  Future<void> setMaxNetworkResponseBytes(int bytes) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(maxNetworkResponseBytes: bytes));
  }

  Future<void> setRssUserAgent(String value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(rssUserAgent: value));
  }

  Future<void> setWebUserAgent(String value) async {
    final cur = state.valueOrNull ?? AppSettings.defaults();
    await _saveQuietly(cur.copyWith(webUserAgent: value));
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
