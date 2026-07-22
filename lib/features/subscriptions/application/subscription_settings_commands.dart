import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/repository_providers.dart';

/// Persists settings owned by an individual feed or category.
///
/// These settings are client-only, including for remote-backed accounts.
abstract final class SubscriptionSettingsCommands {
  static Future<void> updateFeedSettings(
    WidgetRef ref, {
    required int feedId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) {
    return ref
        .read(feedRepositoryProvider)
        .updateSettings(
          id: feedId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
          autoTranslate: autoTranslate,
          updateAutoTranslate: updateAutoTranslate,
        );
  }

  static Future<void> updateCategorySettings(
    WidgetRef ref, {
    required int categoryId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) {
    return ref
        .read(categoryRepositoryProvider)
        .updateSettings(
          id: categoryId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
          autoTranslate: autoTranslate,
          updateAutoTranslate: updateAutoTranslate,
        );
  }
}
