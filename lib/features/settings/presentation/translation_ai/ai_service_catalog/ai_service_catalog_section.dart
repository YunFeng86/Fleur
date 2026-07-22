import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/utils/context_extensions.dart';

import 'ai_service_add_flow.dart';
import 'ai_service_editor_dialog.dart';
import '../ai_service_api_type_display.dart';

enum _AiServiceAction { setDefault, edit, delete }

/// Complete workflow for creating, editing, enabling, and selecting AI services.
class AiServiceCatalogSection extends ConsumerWidget {
  const AiServiceCatalogSection({
    super.key,
    required this.settings,
    required this.targetController,
  });

  final TranslationAiSettings settings;
  final SettingsTargetController targetController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    Future<void> editAiService(AiServiceConfig service) {
      return showAiServiceEditorDialog(
        context,
        ref,
        template: null,
        existing: service,
      );
    }

    Future<void> confirmDeleteAiService(AiServiceConfig service) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.delete),
            content: Text('${l10n.delete} "${service.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      await ref
          .read(translationAiSettingsProvider.notifier)
          .deleteAiService(service.id);
      if (!context.mounted) return;
      context.showSuccess(l10n.done);
    }

    Widget buildCatalogRow(AiServiceConfig service) {
      final isDefault = service.id == settings.defaultAiServiceId;
      final theme = Theme.of(context);
      final subtitleText = [
        apiTypeLabel(service.apiType),
        if (service.baseUrl.trim().isNotEmpty) service.baseUrl.trim(),
        if (service.defaultModel.trim().isNotEmpty)
          l10n.modelSummary(service.defaultModel.trim()),
      ].join(' \u00B7 ');

      Future<void> handleAction(_AiServiceAction action) async {
        switch (action) {
          case _AiServiceAction.setDefault:
            await ref
                .read(translationAiSettingsProvider.notifier)
                .setDefaultAiService(service.id);
            if (!context.mounted) return;
            context.showSuccess(l10n.done);
            return;
          case _AiServiceAction.edit:
            await editAiService(service);
            return;
          case _AiServiceAction.delete:
            await confirmDeleteAiService(service);
            return;
        }
      }

      Widget buildMenuButton() {
        return AppMenuButton<_AiServiceAction>(
          tooltip: l10n.more,
          icon: FleurIcons.moreVertical,
          items: [
            AppMenuItem(
              value: _AiServiceAction.setDefault,
              label: isDefault ? l10n.defaultAlreadySet : l10n.setAsDefault,
            ),
            AppMenuItem(value: _AiServiceAction.edit, label: l10n.edit),
            AppMenuItem(
              value: _AiServiceAction.delete,
              label: l10n.delete,
              destructive: true,
            ),
          ],
          onSelected: (action) => unawaited(handleAction(action)),
        );
      }

      Widget buildToggle({bool showLabel = false}) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              Text(
                service.enabled ? l10n.enabled : l10n.off,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Switch.adaptive(
              value: service.enabled,
              onChanged: (enabled) => unawaited(
                ref
                    .read(translationAiSettingsProvider.notifier)
                    .setAiServiceEnabled(service.id, enabled),
              ),
            ),
          ],
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final useCompactActions = constraints.maxWidth < 560;
          if (useCompactActions) {
            return InkWell(
              onTap: () => unawaited(editAiService(service)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(apiTypeIcon(service.apiType)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDefault)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(FleurIcons.starActive, size: 18),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                service.enabled ? l10n.enabled : l10n.off,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Switch.adaptive(
                                value: service.enabled,
                                onChanged: (enabled) => unawaited(
                                  ref
                                      .read(
                                        translationAiSettingsProvider.notifier,
                                      )
                                      .setAiServiceEnabled(service.id, enabled),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    buildMenuButton(),
                  ],
                ),
              ),
            );
          }

          return SettingsTile(
            leading: Icon(apiTypeIcon(service.apiType)),
            title: Row(
              children: [
                Expanded(child: Text(service.name)),
                if (isDefault)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FleurIcons.starActive, size: 18),
                  ),
              ],
            ),
            subtitle: Text(
              subtitleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [buildToggle(), buildMenuButton()],
            ),
            onTap: () => unawaited(editAiService(service)),
          );
        },
      );
    }

    return SettingsSection(
      title: l10n.aiServices,
      bottomSpacing: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SettingsTargetAnchor(
              id: 'translation_ai.services.add',
              controller: targetController,
              child: SettingsActionButton(
                key: const Key('translation_ai_add_service_button'),
                onPressed: () => unawaited(showAddAiServiceFlow(context, ref)),
                icon: const Icon(FleurIcons.add),
                variant: SettingsActionButtonVariant.filled,
                label: Text(l10n.addAiService),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            padding: settings.aiServices.isEmpty
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: settings.aiServices.isEmpty
                ? Text(
                    l10n.aiServicesEmptyState,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: settings.aiServices.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        buildCatalogRow(settings.aiServices[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
