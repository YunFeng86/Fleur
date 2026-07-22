import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/settings/app_settings.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/language_utils.dart';
import '../../../utils/platform.dart';
import '../settings_targets.dart';
import '../widgets/settings_controls.dart';

class AppPreferencesTab extends ConsumerWidget {
  const AppPreferencesTab({
    super.key,
    required this.targetController,
    this.showPageTitle = true,
  });

  final SettingsTargetController targetController;
  final bool showPageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? AppSettings.defaults();
    final selectedLocaleTag = appSettings.localeTag == null
        ? null
        : normalizeAppLocaleTag(appSettings.localeTag!);

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
          SectionHeader(title: l10n.appPreferences),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.language,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTargetAnchor(
              id: 'app_preferences.language.system',
              controller: targetController,
              child: SettingsControlRow(
                title: Text(l10n.systemLanguage),
                control: SettingsSelectField<String?>(
                  key: const Key('app_preferences_language_select'),
                  value: selectedLocaleTag,
                  options: [
                    SettingsSelectOption<String?>(
                      value: null,
                      label: Text(l10n.systemLanguage),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'zh-Hans',
                      label: const Text('简体中文'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'zh-Hant',
                      label: const Text('繁體中文'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'en',
                      label: const Text('English'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'de',
                      label: const Text('Deutsch (Beta)'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'es',
                      label: const Text('Español (Beta)'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'fr',
                      label: const Text('Français (Beta)'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'ja',
                      label: const Text('日本語 (Beta)'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'ko',
                      label: const Text('한국어 (Beta)'),
                    ),
                    SettingsSelectOption<String?>(
                      value: 'pt-BR',
                      label: const Text('Português (Brasil) (Beta)'),
                    ),
                  ],
                  onChanged: (v) {
                    unawaited(() async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setLocaleTag(v);
                      if (!context.mounted) return;
                      if (!isMacOS) return;
                      context.showSnack(l10n.macosMenuLanguageRestartHint);
                    }());
                  },
                ),
              ),
            ),
          ),
        ),
        SettingsSection(
          title: l10n.readerSettings,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsTargetAnchor(
                  id: 'app_preferences.reader_behavior.auto_mark_read',
                  controller: targetController,
                  child: SettingsSwitchTile(
                    title: Text(l10n.autoMarkRead),
                    value: appSettings.autoMarkRead,
                    onChanged: (v) => ref
                        .read(appSettingsProvider.notifier)
                        .setAutoMarkRead(v),
                  ),
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          title: l10n.storage,
          bottomSpacing: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCard(
                padding: EdgeInsets.zero,
                child: SettingsTargetAnchor(
                  id: 'app_preferences.storage.clear_image_cache',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.clearImageCache),
                    subtitle: Text(l10n.clearImageCacheSubtitle),
                    control: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SettingsActionButton(
                        key: const Key(
                          'app_preferences_clear_image_cache_button',
                        ),
                        onPressed: () async {
                          await ref.read(cacheManagerProvider).emptyCache();
                          await ref.read(imageMetaStoreProvider).clear();
                          if (!context.mounted) return;
                          context.showSnack(l10n.cacheCleared);
                        },
                        label: Text(l10n.clearImageCache),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SettingsCard(
                padding: EdgeInsets.zero,
                child: SettingsTargetAnchor(
                  id: 'app_preferences.storage.cleanup_read_articles',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.cleanupReadArticles),
                    control: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsSelectField<int?>(
                          key: const Key('app_preferences_cleanup_read_select'),
                          value: appSettings.cleanupReadOlderThanDays,
                          options: [
                            SettingsSelectOption<int?>(
                              value: null,
                              label: Text(l10n.off),
                            ),
                            for (final d in const [7, 30, 90, 180])
                              SettingsSelectOption<int?>(
                                value: d,
                                label: Text(l10n.days(d)),
                              ),
                          ],
                          onChanged: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setCleanupReadOlderThanDays(v),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: SettingsActionButton(
                            key: const Key(
                              'app_preferences_cleanup_now_button',
                            ),
                            onPressed:
                                appSettings.cleanupReadOlderThanDays == null
                                ? null
                                : () async {
                                    final days =
                                        appSettings.cleanupReadOlderThanDays!;
                                    final cutoff = DateTime.now()
                                        .toUtc()
                                        .subtract(Duration(days: days));
                                    final n = await ref
                                        .read(articleRepositoryProvider)
                                        .deleteReadUnstarredOlderThan(cutoff);
                                    if (!context.mounted) return;
                                    context.showSnack(l10n.cleanedArticles(n));
                                  },
                            label: Text(l10n.cleanupNow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
