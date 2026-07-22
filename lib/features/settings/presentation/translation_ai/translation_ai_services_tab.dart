import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/ui/settings/widgets/section_header.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';

import 'ai_service_catalog/ai_service_catalog_section.dart';
import 'ai_summary_policy_section.dart';
import 'translation_configuration_section.dart';

/// Settings scene for translation providers, AI summary behavior, and AI services.
class TranslationAiServicesTab extends ConsumerWidget {
  const TranslationAiServicesTab({
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
    final settingsAsync = ref.watch(translationAiSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text(l10n.errorMessage(error.toString()))),
      data: (settings) {
        return SettingsPageBody(
          children: [
            if (showPageTitle) ...[
              SectionHeader(title: l10n.translationAndAiServices),
              const SizedBox(height: 8),
            ],
            TranslationConfigurationSection(
              settings: settings,
              appSettings: appSettings,
              targetController: targetController,
            ),
            AiSummaryPolicySection(
              settings: settings,
              targetController: targetController,
            ),
            AiServiceCatalogSection(
              settings: settings,
              targetController: targetController,
            ),
          ],
        );
      },
    );
  }
}
