import '../../../models/feed.dart';
import '../../../models/category.dart';
import '../../../services/settings/app_settings.dart';

class SettingsInheritanceHelper {
  static bool resolveFilterEnabled(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedFilterEnabled = feed?.filterEnabled;
    if (feedFilterEnabled != null) return feedFilterEnabled;

    final categoryFilterEnabled = category?.filterEnabled;
    if (categoryFilterEnabled != null) return categoryFilterEnabled;
    return appSettings.filterEnabled;
  }

  static String resolveFilterKeywords(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedFilterKeywords = feed?.filterKeywords;
    if (feedFilterKeywords != null && feedFilterKeywords.isNotEmpty) {
      return feedFilterKeywords;
    }

    final categoryFilterKeywords = category?.filterKeywords;
    if (categoryFilterKeywords != null && categoryFilterKeywords.isNotEmpty) {
      return categoryFilterKeywords;
    }
    return appSettings.filterKeywords;
  }

  static bool resolveSyncEnabled(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedSyncEnabled = feed?.syncEnabled;
    if (feedSyncEnabled != null) return feedSyncEnabled;

    final categorySyncEnabled = category?.syncEnabled;
    if (categorySyncEnabled != null) return categorySyncEnabled;
    return appSettings.syncEnabled;
  }

  static bool resolveSyncImages(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedSyncImages = feed?.syncImages;
    if (feedSyncImages != null) return feedSyncImages;

    final categorySyncImages = category?.syncImages;
    if (categorySyncImages != null) return categorySyncImages;
    return appSettings.syncImages;
  }

  static bool resolveSyncWebPages(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedSyncWebPages = feed?.syncWebPages;
    if (feedSyncWebPages != null) return feedSyncWebPages;

    final categorySyncWebPages = category?.syncWebPages;
    if (categorySyncWebPages != null) return categorySyncWebPages;
    return appSettings.syncWebPages;
  }

  static bool resolveShowAiSummary(
    Feed? feed,
    Category? category,
    AppSettings appSettings,
  ) {
    final feedShowAiSummary = feed?.showAiSummary;
    if (feedShowAiSummary != null) return feedShowAiSummary;

    final categoryShowAiSummary = category?.showAiSummary;
    if (categoryShowAiSummary != null) return categoryShowAiSummary;
    return appSettings.showAiSummary;
  }
}
