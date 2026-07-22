import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/utils/context_extensions.dart';
import 'package:fleur/utils/prompt_template.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import 'ai_service_catalog/ai_service_add_flow.dart';
import 'ai_service_catalog/ai_service_templates.dart';
import 'prompt_template_editor_dialog.dart';

/// Complete workflow for choosing how AI summaries are produced.
class AiSummaryPolicySection extends ConsumerWidget {
  const AiSummaryPolicySection({
    super.key,
    required this.settings,
    required this.targetController,
  });

  final TranslationAiSettings settings;
  final SettingsTargetController targetController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final defaultAiSummaryPromptTemplate = l10n.defaultAiSummaryPromptTemplate(
      PromptTemplate.token(PromptTemplate.varLanguage),
      PromptTemplate.token(PromptTemplate.varTitle),
      PromptTemplate.token(PromptTemplate.varContent),
    );
    final effectiveAiSummaryPrompt =
        (settings.aiSummaryPrompt ?? defaultAiSummaryPromptTemplate).trim();

    String? serviceNameById(String serviceId) {
      for (final service in settings.aiServices) {
        if (service.id == serviceId) return service.name;
      }
      return null;
    }

    final defaultAiServiceId = settings.defaultAiServiceId;
    final defaultAiServiceName = defaultAiServiceId == null
        ? null
        : (serviceNameById(defaultAiServiceId) ?? defaultAiServiceId);
    final explicitAiSummaryServiceId = settings.aiSummaryServiceId;
    final effectiveAiSummaryServiceId =
        explicitAiSummaryServiceId ?? defaultAiServiceId;
    final effectiveAiSummaryServiceName = effectiveAiSummaryServiceId == null
        ? null
        : (serviceNameById(effectiveAiSummaryServiceId) ??
              effectiveAiSummaryServiceId);
    final aiSummaryServiceSubtitle = effectiveAiSummaryServiceName == null
        ? l10n.aiNotConfigured
        : (explicitAiSummaryServiceId == null
              ? '${l10n.defaultOption} \u00B7 $effectiveAiSummaryServiceName'
              : effectiveAiSummaryServiceName);

    Future<void> pickAiSummaryService() async {
      final enabled = settings.aiServices
          .where((service) => service.enabled)
          .toList(growable: false);
      final picked =
          await showModalBottomSheet<({bool isDefault, String? value})>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) {
              return SafeArea(
                top: false,
                child: AppScrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          l10n.aiSummaryService,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.defaultOption),
                        subtitle: Text(
                          defaultAiServiceName ?? l10n.aiNotConfigured,
                        ),
                        trailing: explicitAiSummaryServiceId == null
                            ? const Icon(FleurIcons.check)
                            : null,
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop(const (isDefault: true, value: null)),
                      ),
                      for (final service in enabled)
                        ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(service.name)),
                              if (service.id == defaultAiServiceId)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(FleurIcons.starActive, size: 18),
                                ),
                            ],
                          ),
                          subtitle: Text(apiTypeLabel(service.apiType)),
                          trailing: explicitAiSummaryServiceId == service.id
                              ? const Icon(FleurIcons.check)
                              : null,
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop((isDefault: false, value: service.id)),
                        ),
                      if (enabled.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            l10n.aiNotConfigured,
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ListTile(
                        leading: const Icon(FleurIcons.add),
                        title: Text(l10n.addAiService),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(showAddAiServiceFlow(context, ref));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
      if (picked == null) return;
      await ref
          .read(translationAiSettingsProvider.notifier)
          .setAiSummaryServiceId(picked.isDefault ? null : picked.value);
      if (!context.mounted) return;
      context.showSuccess(l10n.done);
    }

    Future<void> editAiSummaryPrompt() {
      return showPromptTemplateEditorDialog(
        context,
        title: l10n.aiSummaryPrompt,
        customPrompt: settings.aiSummaryPrompt,
        defaultTemplate: defaultAiSummaryPromptTemplate,
        onSave: (next) => ref
            .read(translationAiSettingsProvider.notifier)
            .setAiSummaryPrompt(next),
      );
    }

    Future<void> editTpmLimit() async {
      final picked = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          final controller = TextEditingController(
            text: settings.tpmLimit.toString(),
          );
          return AlertDialog(
            title: Text(l10n.tpmLimit),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tpmLimitSubtitle,
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.tpmLimit),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final raw = controller.text.trim();
                  final value = int.tryParse(raw);
                  Navigator.of(dialogContext).pop(value ?? 0);
                },
                child: Text(l10n.done),
              ),
            ],
          );
        },
      );
      if (picked == null) return;
      await ref
          .read(translationAiSettingsProvider.notifier)
          .setTpmLimit(picked);
      if (!context.mounted) return;
      context.showSuccess(l10n.done);
    }

    return SettingsSection(
      title: l10n.aiSummary,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: SettingsTileGroup(
          children: [
            SettingsTargetAnchor(
              id: 'translation_ai.summary.service',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.aiSummary),
                title: Text(l10n.aiSummaryService),
                subtitle: Text(aiSummaryServiceSubtitle),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: () => unawaited(pickAiSummaryService()),
              ),
            ),
            SettingsTargetAnchor(
              id: 'translation_ai.summary.prompt',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.prompt),
                title: Text(l10n.aiSummaryPrompt),
                subtitle: Text(
                  effectiveAiSummaryPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: () => unawaited(editAiSummaryPrompt()),
              ),
            ),
            SettingsTargetAnchor(
              id: 'translation_ai.summary.tpm_limit',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.speed),
                title: Text(l10n.tpmLimit),
                subtitle: Text(
                  '${settings.tpmLimit} \u00B7 ${l10n.tpmLimitSubtitle}',
                ),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: () => unawaited(editTpmLimit()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
