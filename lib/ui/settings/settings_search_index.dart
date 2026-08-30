import 'package:flutter/widgets.dart';

import '../../app/settings_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/fleur_icons.dart';

enum SettingsSearchEntryKind { page, section, setting }

class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.tab,
    required this.kind,
    required this.title,
    required this.section,
    required this.subtitle,
    required this.keywords,
    required this.targetId,
  });

  final String id;
  final SettingsTab tab;
  final SettingsSearchEntryKind kind;
  final String title;
  final String section;
  final String subtitle;
  final List<String> keywords;
  final String? targetId;
}

List<SettingsSearchEntry> buildSettingsSearchEntries(AppLocalizations l10n) {
  return [
    _page(
      SettingsTab.appPreferences,
      l10n.appPreferences,
      iconKeywords: const ['general', 'preferences', 'app'],
    ),
    _page(
      SettingsTab.appearance,
      l10n.appearance,
      iconKeywords: const ['theme', 'color', 'display', 'reader'],
    ),
    _page(
      SettingsTab.subscriptions,
      l10n.subscriptions,
      iconKeywords: const ['feeds', 'rss', 'folders'],
    ),
    _page(
      SettingsTab.groupingAndSorting,
      l10n.groupingAndSorting,
      iconKeywords: const ['group', 'sort', 'order', 'list'],
    ),
    _page(
      SettingsTab.services,
      l10n.services,
      iconKeywords: const ['account', 'sync', 'refresh', 'remote'],
    ),
    _page(
      SettingsTab.translationAndAiServices,
      l10n.translationAndAiServices,
      iconKeywords: const ['translation', 'translate', 'ai', 'summary'],
    ),
    _page(
      SettingsTab.about,
      l10n.about,
      iconKeywords: const ['version', 'license', 'shortcuts'],
    ),
    _section(
      id: 'app_preferences.language',
      tab: SettingsTab.appPreferences,
      title: l10n.language,
      keywords: ['locale', 'system language', l10n.systemLanguage],
    ),
    _setting(
      id: 'app_preferences.language.system',
      tab: SettingsTab.appPreferences,
      title: l10n.systemLanguage,
      section: l10n.language,
      targetId: 'app_preferences.language.system',
      keywords: [l10n.language, 'locale', 'ui language'],
    ),
    _section(
      id: 'app_preferences.reader_behavior',
      tab: SettingsTab.appPreferences,
      title: l10n.readerSettings,
      keywords: ['behavior', 'read', 'mark read'],
    ),
    _setting(
      id: 'app_preferences.reader_behavior.auto_mark_read',
      tab: SettingsTab.appPreferences,
      title: l10n.autoMarkRead,
      section: l10n.readerSettings,
      targetId: 'app_preferences.reader_behavior.auto_mark_read',
      keywords: ['read', 'opened', 'behavior'],
    ),
    _section(
      id: 'app_preferences.storage',
      tab: SettingsTab.appPreferences,
      title: l10n.storage,
      keywords: ['cache', 'cleanup', 'disk'],
    ),
    _setting(
      id: 'app_preferences.storage.clear_image_cache',
      tab: SettingsTab.appPreferences,
      title: l10n.clearImageCache,
      section: l10n.storage,
      subtitle: l10n.clearImageCacheSubtitle,
      targetId: 'app_preferences.storage.clear_image_cache',
      keywords: ['cache', 'image', 'offline'],
    ),
    _setting(
      id: 'app_preferences.storage.cleanup_read_articles',
      tab: SettingsTab.appPreferences,
      title: l10n.cleanupReadArticles,
      section: l10n.storage,
      targetId: 'app_preferences.storage.cleanup_read_articles',
      keywords: ['cleanup', 'read', 'articles', 'storage'],
    ),
    _section(
      id: 'appearance.theme',
      tab: SettingsTab.appearance,
      title: l10n.applicationAppearance,
      keywords: ['mode', 'light', 'dark', 'system', 'accent'],
    ),
    _setting(
      id: 'appearance.theme.mode',
      tab: SettingsTab.appearance,
      title: l10n.themeMode,
      section: l10n.applicationAppearance,
      targetId: 'appearance.theme.mode',
      keywords: [l10n.system, l10n.light, l10n.dark],
    ),
    _setting(
      id: 'appearance.theme.colors',
      tab: SettingsTab.appearance,
      title: l10n.seedColorPreset,
      section: l10n.applicationAppearance,
      subtitle: l10n.seedColorPresetSubtitle,
      targetId: 'appearance.theme.colors',
      keywords: [
        l10n.dynamicColor,
        'dynamic color',
        'material you',
        'seed',
        'palette',
        'accent',
        'color',
      ],
    ),
    _section(
      id: 'appearance.reader',
      tab: SettingsTab.appearance,
      title: l10n.readerAppearance,
      keywords: ['display', 'font', 'line', 'width', 'theme'],
    ),
    _setting(
      id: 'appearance.reader.font_family',
      tab: SettingsTab.appearance,
      title: l10n.readerFontFamily,
      section: l10n.readerAppearance,
      targetId: 'appearance.reader.font_family',
      keywords: [
        'font',
        'font stack',
        'advanced font settings',
        'standard font',
        'custom font',
        'serif',
        'sans',
        'mono',
        l10n.fontSettings,
        l10n.advancedFontSettings,
        l10n.standardFont,
        l10n.readerFontSerif,
        l10n.readerFontSans,
        l10n.readerFontMono,
      ],
    ),
    _setting(
      id: 'appearance.reader.font_size',
      tab: SettingsTab.appearance,
      title: l10n.fontSize,
      section: l10n.readerAppearance,
      targetId: 'appearance.reader.font_size',
      keywords: [
        'font',
        'text',
        'size',
        'reader',
        l10n.fontSizeExtraSmall,
        l10n.fontSizeMediumRecommended,
      ],
    ),
    _setting(
      id: 'appearance.reader.line_height',
      tab: SettingsTab.appearance,
      title: l10n.lineHeight,
      section: l10n.readerAppearance,
      targetId: 'appearance.reader.line_height',
      keywords: [
        'line',
        'spacing',
        'reader',
        l10n.lineHeightCompact,
        l10n.lineHeightRelaxed,
      ],
    ),
    _setting(
      id: 'appearance.reader.width',
      tab: SettingsTab.appearance,
      title: l10n.readingWidth,
      section: l10n.readerAppearance,
      targetId: 'appearance.reader.width',
      keywords: ['margin', 'padding', 'reader', 'width', l10n.readingWidth],
    ),
    _setting(
      id: 'appearance.reader.theme',
      tab: SettingsTab.appearance,
      title: l10n.readerTheme,
      section: l10n.readerAppearance,
      targetId: 'appearance.reader.theme',
      keywords: [
        'theme',
        'texture',
        'surface',
        'paper',
        'sepia',
        'dim',
        l10n.readerThemePaper,
        l10n.readerThemeSepia,
        l10n.readerThemeDim,
        l10n.readerTheme,
      ],
    ),
    _setting(
      id: 'appearance.fonts.advanced',
      tab: SettingsTab.appearance,
      title: l10n.advancedFontSettings,
      section: l10n.readerAppearance,
      targetId: 'appearance.fonts.advanced',
      keywords: [
        'advanced font settings',
        'font stack',
        'custom font',
        'minimum font size',
        'standard font',
        'math font',
        'monospace',
        l10n.fontSettings,
        l10n.minimumFontSize,
        l10n.standardFont,
        l10n.serifFont,
        l10n.sansSerifFont,
        l10n.fixedWidthFont,
        l10n.mathFont,
      ],
    ),
    _setting(
      id: 'appearance.code.font',
      tab: SettingsTab.appearance,
      title: l10n.fontsAndCode,
      section: l10n.readerAppearance,
      targetId: 'appearance.fonts.advanced',
      keywords: [
        'code',
        'font',
        'custom font',
        'mono',
        'monospace',
        'font stack',
        'advanced font settings',
        l10n.codeFontFamily,
        l10n.codeFontSystemMono,
        l10n.codeFontStack,
        l10n.fixedWidthFont,
        l10n.advancedFontSettings,
      ],
    ),
    _setting(
      id: 'appearance.code.font_size',
      tab: SettingsTab.appearance,
      title: l10n.codeFontSize,
      section: l10n.readerAppearance,
      targetId: 'appearance.fonts.advanced',
      keywords: [
        'code',
        'font',
        'size',
        l10n.fontsAndCode,
        l10n.codeTypography,
        l10n.codeFontSizeFollowReader,
        l10n.codeFontSizeOneStepDown,
      ],
    ),
    _setting(
      id: 'appearance.code.line_height',
      tab: SettingsTab.appearance,
      title: l10n.codeLineHeight,
      section: l10n.readerAppearance,
      targetId: 'appearance.fonts.advanced',
      keywords: [
        'code',
        'line',
        'height',
        'spacing',
        l10n.fontsAndCode,
        l10n.codeTypography,
      ],
    ),
    _setting(
      id: 'appearance.code.wrap',
      tab: SettingsTab.appearance,
      title: l10n.codeSoftWrap,
      section: l10n.readerAppearance,
      targetId: 'appearance.code.wrap',
      keywords: ['code', 'wrap', 'soft wrap', 'line wrap', l10n.codeSoftWrap],
    ),
    _section(
      id: 'subscriptions.defaults',
      tab: SettingsTab.subscriptions,
      title: l10n.globalDefaults,
      keywords: ['feeds', 'folders', 'defaults'],
    ),
    _section(
      id: 'grouping_sorting.group',
      tab: SettingsTab.groupingAndSorting,
      title: l10n.groupBy,
      keywords: ['grouping', 'day'],
    ),
    _setting(
      id: 'grouping_sorting.group.mode',
      tab: SettingsTab.groupingAndSorting,
      title: l10n.groupBy,
      section: l10n.groupingAndSorting,
      targetId: 'grouping_sorting.group.mode',
      keywords: [l10n.groupByDay, l10n.groupNone],
    ),
    _section(
      id: 'grouping_sorting.sort',
      tab: SettingsTab.groupingAndSorting,
      title: l10n.sortOrder,
      keywords: ['sort', 'newest', 'oldest'],
    ),
    _setting(
      id: 'grouping_sorting.sort.order',
      tab: SettingsTab.groupingAndSorting,
      title: l10n.sortOrder,
      section: l10n.groupingAndSorting,
      targetId: 'grouping_sorting.sort.order',
      keywords: [l10n.sortNewestFirst, l10n.sortOldestFirst],
    ),
    _section(
      id: 'services.account',
      tab: SettingsTab.services,
      title: l10n.account,
      keywords: ['account', 'login', 'local', 'miniflux', 'fever'],
    ),
    _setting(
      id: 'services.account.add',
      tab: SettingsTab.services,
      title: l10n.addOrRegisterAccount,
      section: l10n.account,
      targetId: 'services.account.add',
      keywords: ['account', 'add', 'register'],
    ),
    _section(
      id: 'services.refresh',
      tab: SettingsTab.services,
      title: l10n.refreshAll,
      subtitle: l10n.autoRefreshSubtitle,
      keywords: ['refresh', 'sync', 'interval'],
    ),
    _setting(
      id: 'services.refresh.interval',
      tab: SettingsTab.services,
      title: l10n.refreshAll,
      section: l10n.refreshAll,
      subtitle: l10n.autoRefreshSubtitle,
      targetId: 'services.refresh.interval',
      keywords: ['interval', 'auto refresh', 'sync'],
    ),
    _setting(
      id: 'services.refresh.concurrency',
      tab: SettingsTab.services,
      title: l10n.refreshConcurrency,
      section: l10n.refreshAll,
      targetId: 'services.refresh.concurrency',
      keywords: ['concurrency', 'parallel', 'refresh'],
    ),
    _section(
      id: 'services.remote_sync_strategy',
      tab: SettingsTab.services,
      title: l10n.remoteSyncStrategy,
      keywords: ['remote', 'sync', 'entries', 'miniflux'],
    ),
    _setting(
      id: 'services.remote.entries_limit',
      tab: SettingsTab.services,
      title: l10n.remoteEntriesLimit,
      section: l10n.remoteSyncStrategy,
      targetId: 'services.remote.entries_limit',
      keywords: ['entries', 'limit', 'sync'],
    ),
    _setting(
      id: 'services.remote.fetch_concurrency',
      tab: SettingsTab.services,
      title: l10n.remoteFetchConcurrency,
      section: l10n.remoteSyncStrategy,
      subtitle: l10n.remoteFetchConcurrencySubtitle,
      targetId: 'services.remote.fetch_concurrency',
      keywords: ['remote', 'concurrency', 'batch'],
    ),
    _setting(
      id: 'services.remote.miniflux_web_fetch_mode',
      tab: SettingsTab.services,
      title: l10n.minifluxWebFetchMode,
      section: l10n.remoteSyncStrategy,
      subtitle: l10n.minifluxWebFetchModeSubtitle,
      targetId: 'services.remote.miniflux_web_fetch_mode',
      keywords: ['web', 'readability', 'fetch content', 'miniflux'],
    ),
    _setting(
      id: 'services.remote.max_network_response_bytes',
      tab: SettingsTab.services,
      title: l10n.maxNetworkResponseBytes,
      section: l10n.remoteSyncStrategy,
      subtitle: l10n.maxNetworkResponseBytesSubtitle,
      targetId: 'services.remote.max_network_response_bytes',
      keywords: ['network', 'response', 'size', 'limit'],
    ),
    _section(
      id: 'translation_ai.translation',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.translation,
      keywords: ['translate', 'provider', 'language'],
    ),
    _setting(
      id: 'translation_ai.translation.provider',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.translationProvider,
      section: l10n.translation,
      targetId: 'translation_ai.translation.provider',
      keywords: ['translate', 'provider', 'google', 'bing', 'deepl'],
    ),
    _setting(
      id: 'translation_ai.translation.target_language',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.targetLanguage,
      section: l10n.translation,
      targetId: 'translation_ai.translation.target_language',
      keywords: ['language', 'translate'],
    ),
    _setting(
      id: 'translation_ai.translation.prompt',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.aiTranslationPrompt,
      section: l10n.translation,
      targetId: 'translation_ai.translation.prompt',
      keywords: ['prompt', 'ai', 'translate'],
    ),
    _section(
      id: 'translation_ai.summary',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.aiSummary,
      keywords: ['ai', 'summary', 'prompt'],
    ),
    _setting(
      id: 'translation_ai.summary.service',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.aiSummaryService,
      section: l10n.aiSummary,
      targetId: 'translation_ai.summary.service',
      keywords: ['ai', 'summary', 'service'],
    ),
    _setting(
      id: 'translation_ai.summary.prompt',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.aiSummaryPrompt,
      section: l10n.aiSummary,
      targetId: 'translation_ai.summary.prompt',
      keywords: ['ai', 'summary', 'prompt'],
    ),
    _setting(
      id: 'translation_ai.summary.tpm_limit',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.tpmLimit,
      section: l10n.aiSummary,
      targetId: 'translation_ai.summary.tpm_limit',
      keywords: ['token', 'rate', 'limit', 'queue'],
    ),
    _section(
      id: 'translation_ai.services',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.aiServices,
      keywords: ['ai', 'service', 'model', 'api'],
    ),
    _setting(
      id: 'translation_ai.services.add',
      tab: SettingsTab.translationAndAiServices,
      title: l10n.addAiService,
      section: l10n.aiServices,
      targetId: 'translation_ai.services.add',
      keywords: ['ai', 'service', 'api', 'model'],
    ),
    _section(
      id: 'about.app',
      tab: SettingsTab.about,
      title: l10n.about,
      keywords: ['version', 'build', 'data', 'logs'],
    ),
    _section(
      id: 'about.license',
      tab: SettingsTab.about,
      title: l10n.openSourceLicense,
      keywords: ['license', 'mit'],
    ),
    _section(
      id: 'about.shortcuts',
      tab: SettingsTab.about,
      title: l10n.keyboardShortcuts,
      keywords: ['keyboard', 'shortcut', 'hotkey'],
    ),
  ];
}

List<SettingsSearchEntry> searchSettingsEntries(
  List<SettingsSearchEntry> entries,
  String query,
) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) {
    return entries
        .where((entry) => entry.kind == SettingsSearchEntryKind.page)
        .toList(growable: false);
  }

  final scored = <({SettingsSearchEntry entry, int score})>[];
  for (final entry in entries) {
    final score = _scoreEntry(entry, normalizedQuery);
    if (score == null) continue;
    scored.add((entry: entry, score: score));
  }

  scored.sort((a, b) {
    final scoreCompare = a.score.compareTo(b.score);
    if (scoreCompare != 0) return scoreCompare;
    final kindCompare = a.entry.kind.index.compareTo(b.entry.kind.index);
    if (kindCompare != 0) return kindCompare;
    return a.entry.title.compareTo(b.entry.title);
  });
  return [for (final item in scored) item.entry];
}

IconData settingsSearchEntryIcon(SettingsSearchEntry entry) {
  return switch (entry.tab) {
    SettingsTab.appPreferences => FleurIcons.appPreferences,
    SettingsTab.appearance => FleurIcons.appearance,
    SettingsTab.subscriptions => FleurIcons.feeds,
    SettingsTab.groupingAndSorting => FleurIcons.grouping,
    SettingsTab.services => FleurIcons.services,
    SettingsTab.translationAndAiServices => FleurIcons.translationAi,
    SettingsTab.about => FleurIcons.about,
  };
}

String settingsSearchEntryKindLabel(
  AppLocalizations l10n,
  SettingsSearchEntryKind kind,
) {
  return switch (kind) {
    SettingsSearchEntryKind.page => l10n.settingsSearchPageLabel,
    SettingsSearchEntryKind.section => l10n.settingsSearchSectionLabel,
    SettingsSearchEntryKind.setting => l10n.settingsSearchSettingLabel,
  };
}

SettingsSearchEntry _page(
  SettingsTab tab,
  String title, {
  required List<String> iconKeywords,
}) {
  return SettingsSearchEntry(
    id: 'page.${tab.queryValue}',
    tab: tab,
    kind: SettingsSearchEntryKind.page,
    title: title,
    section: '',
    subtitle: '',
    keywords: iconKeywords,
    targetId: null,
  );
}

SettingsSearchEntry _section({
  required String id,
  required SettingsTab tab,
  required String title,
  required List<String> keywords,
  String subtitle = '',
}) {
  return SettingsSearchEntry(
    id: id,
    tab: tab,
    kind: SettingsSearchEntryKind.section,
    title: title,
    section: '',
    subtitle: subtitle,
    keywords: keywords,
    targetId: null,
  );
}

SettingsSearchEntry _setting({
  required String id,
  required SettingsTab tab,
  required String title,
  required String section,
  required String targetId,
  required List<String> keywords,
  String subtitle = '',
}) {
  return SettingsSearchEntry(
    id: id,
    tab: tab,
    kind: SettingsSearchEntryKind.setting,
    title: title,
    section: section,
    subtitle: subtitle,
    keywords: keywords,
    targetId: targetId,
  );
}

int? _scoreEntry(SettingsSearchEntry entry, String query) {
  final title = _normalize(entry.title);
  final section = _normalize(entry.section);
  final subtitle = _normalize(entry.subtitle);
  final tab = _normalize(entry.tab.queryValue.replaceAll('-', ' '));
  final keywords = entry.keywords.map(_normalize).where((s) => s.isNotEmpty);

  if (title == query) return 0;
  if (title.startsWith(query)) return 10;
  if (title.contains(query)) return 20;
  if (keywords.any((keyword) => keyword == query)) return 30;
  if (keywords.any((keyword) => keyword.startsWith(query))) return 40;
  if (keywords.any((keyword) => keyword.contains(query))) return 50;
  if (section.startsWith(query) || tab.startsWith(query)) return 60;
  if (section.contains(query) || tab.contains(query)) return 70;
  if (subtitle.contains(query)) return 80;
  return null;
}

String _normalize(String input) {
  return input.trim().toLowerCase();
}
