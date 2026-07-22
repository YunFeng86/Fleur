import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/dialogs/text_input_dialog.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/utils/context_extensions.dart';
import 'package:fleur/utils/language_utils.dart';
import 'package:fleur/utils/prompt_template.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import 'prompt_template_editor_dialog.dart';

/// Complete workflow for selecting and configuring translation behavior.
class TranslationConfigurationSection extends ConsumerWidget {
  const TranslationConfigurationSection({
    super.key,
    required this.settings,
    required this.appSettings,
    required this.targetController,
  });

  final TranslationAiSettings settings;
  final AppSettings appSettings;
  final SettingsTargetController targetController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabledServices = settings.aiServices
        .where((service) => service.enabled)
        .toList(growable: false);
    final translationLabel = _translationProviderLabel(
      l10n,
      settings.translationProvider,
      settings,
    );
    final uiLocale = Localizations.localeOf(context);
    final followAppTargetLanguageTag = defaultTargetLanguageTagForAppLocale(
      appSettings.localeTag,
      PlatformDispatcher.instance.locale,
    );
    final effectiveTargetLanguageTag = canonicalLanguageIdentityTag(
      settings.targetLanguageTag ?? followAppTargetLanguageTag,
    );
    final targetLanguageSubtitle = settings.targetLanguageTag == null
        ? '${l10n.followAppLanguage} \u00B7 ${localizedLanguageNameForTag(uiLocale, followAppTargetLanguageTag)}'
        : localizedLanguageNameForTag(uiLocale, effectiveTargetLanguageTag);
    final defaultAiTranslationPromptTemplate = l10n
        .defaultAiTranslationPromptTemplate(
          PromptTemplate.token(PromptTemplate.varLanguage),
          PromptTemplate.token(PromptTemplate.varTitle),
          PromptTemplate.token(PromptTemplate.varContent),
        );
    final effectiveAiTranslationPrompt =
        (settings.aiTranslationPrompt ?? defaultAiTranslationPromptTemplate)
            .trim();

    Future<void> pickTranslationProvider() async {
      final picked = await showModalBottomSheet<TranslationProviderSelection>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          final current = settings.translationProvider;
          final options = <TranslationProviderSelection>[
            const TranslationProviderSelection.googleWeb(),
            const TranslationProviderSelection.bingWeb(),
            const TranslationProviderSelection.baiduApi(),
            const TranslationProviderSelection.deepLApi(),
            const TranslationProviderSelection.deepLX(),
            ...enabledServices.map(
              (service) => TranslationProviderSelection.aiService(service.id),
            ),
          ];

          return SafeArea(
            top: false,
            child: AppScrollbar(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      l10n.translationProvider,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  for (final option in options)
                    ListTile(
                      title: Text(
                        _translationProviderLabel(l10n, option, settings),
                      ),
                      trailing: option == current
                          ? const Icon(FleurIcons.check)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(option),
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
          .setTranslationProvider(picked);
    }

    Future<void> setDeepLXBaseUrl() async {
      final next = await showTextInputDialog(
        context,
        title: l10n.deepLXBaseUrlTitle,
        labelText: l10n.baseUrl,
        hintText: 'https://deeplx.example.com',
        initialText: settings.deepLX.baseUrl,
        keyboardType: TextInputType.url,
        confirmText: l10n.done,
      );
      if (next == null) return;
      final trimmed = next.trim();
      if (trimmed.isNotEmpty) {
        final uri = Uri.tryParse(trimmed);
        if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
          if (!context.mounted) return;
          context.showErrorMessage(l10n.invalidBaseUrl);
          return;
        }
      }
      await ref
          .read(translationAiSettingsProvider.notifier)
          .setDeepLXBaseUrl(trimmed);
      if (!context.mounted) return;
      context.showSuccess(l10n.done);
    }

    Future<void> configureDeepL() async {
      final secrets = ref.read(translationAiSecretStoreProvider);
      final existingKey = await secrets.getDeepLApiKey();
      if (!context.mounted) return;

      final apiKeyController = TextEditingController(text: existingKey ?? '');
      var endpoint = settings.deepL.endpoint;
      var obscure = true;
      var submitting = false;

      Future<void> submit(
        StateSetter setState,
        BuildContext dialogContext,
      ) async {
        if (submitting) return;
        setState(() => submitting = true);
        try {
          final key = apiKeyController.text.trim();
          if (key.isEmpty) {
            await secrets.deleteDeepLApiKey();
          } else {
            await secrets.setDeepLApiKey(key);
          }
          await ref
              .read(translationAiSettingsProvider.notifier)
              .setDeepLEndpoint(endpoint);
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
        } catch (error) {
          if (!dialogContext.mounted) return;
          setState(() => submitting = false);
          dialogContext.showError(error);
        }
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setState) {
              return AlertDialog(
                scrollable: true,
                title: Text(l10n.translationProviderDeepLApi),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.deepLEndpoint,
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.deepLEndpointFree),
                            selected: endpoint == DeepLEndpoint.free,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => endpoint = DeepLEndpoint.free);
                            },
                          ),
                          ChoiceChip(
                            label: Text(l10n.deepLEndpointPro),
                            selected: endpoint == DeepLEndpoint.pro,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => endpoint = DeepLEndpoint.pro);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: apiKeyController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: l10n.apiKey,
                          suffixIcon: IconButton(
                            tooltip: obscure ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.savedApiKeyClearHint,
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () => unawaited(submit(setState, dialogContext)),
                    child: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.done),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> configureBaidu() async {
      final secrets = ref.read(translationAiSecretStoreProvider);
      final existing = await secrets.getBaiduCredentials();
      if (!context.mounted) return;

      final appIdController = TextEditingController(
        text: existing?.appId ?? '',
      );
      final appKeyController = TextEditingController(
        text: existing?.appKey ?? '',
      );
      var obscure = true;
      var submitting = false;

      Future<void> submit(
        StateSetter setState,
        BuildContext dialogContext,
      ) async {
        if (submitting) return;
        final id = appIdController.text.trim();
        final key = appKeyController.text;

        setState(() => submitting = true);
        try {
          if (id.isEmpty || key.isEmpty) {
            await secrets.deleteBaiduCredentials();
          } else {
            await secrets.setBaiduCredentials(appId: id, appKey: key);
          }
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
        } catch (error) {
          if (!dialogContext.mounted) return;
          setState(() => submitting = false);
          dialogContext.showError(error);
        }
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setState) {
              return AlertDialog(
                scrollable: true,
                title: Text(l10n.translationProviderBaiduApi),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: appIdController,
                        decoration: InputDecoration(labelText: l10n.appId),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: appKeyController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: l10n.appKey,
                          suffixIcon: IconButton(
                            tooltip: obscure ? l10n.show : l10n.hide,
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.savedCredentialsClearHint,
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () => unawaited(submit(setState, dialogContext)),
                    child: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.done),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> pickTargetLanguage() async {
      const commonLanguageTags = <String>[
        'en',
        'zh-Hans',
        'zh-Hant',
        'de',
        'es',
        'fr',
        'ja',
        'ko',
        'pt-BR',
        'ru',
      ];
      final current = settings.targetLanguageTag == null
          ? null
          : effectiveTargetLanguageTag;
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
                          l10n.targetLanguage,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      ListTile(
                        title: Text(l10n.followAppLanguage),
                        subtitle: Text(
                          localizedLanguageNameForTag(
                            uiLocale,
                            followAppTargetLanguageTag,
                          ),
                        ),
                        trailing: settings.targetLanguageTag == null
                            ? const Icon(FleurIcons.check)
                            : null,
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop(const (isDefault: true, value: null)),
                      ),
                      for (final tag in commonLanguageTags)
                        ListTile(
                          title: Text(
                            localizedLanguageNameForTag(uiLocale, tag),
                          ),
                          subtitle: Text(tag),
                          trailing: current == tag
                              ? const Icon(FleurIcons.check)
                              : null,
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop((isDefault: false, value: tag)),
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
          .setTargetLanguageTag(picked.isDefault ? null : picked.value);
      if (!context.mounted) return;
      context.showSuccess(l10n.done);
    }

    Future<void> editAiTranslationPrompt() {
      return showPromptTemplateEditorDialog(
        context,
        title: l10n.aiTranslationPrompt,
        customPrompt: settings.aiTranslationPrompt,
        defaultTemplate: defaultAiTranslationPromptTemplate,
        onSave: (next) => ref
            .read(translationAiSettingsProvider.notifier)
            .setAiTranslationPrompt(next),
      );
    }

    return SettingsSection(
      title: l10n.translation,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: SettingsTileGroup(
          children: [
            SettingsTargetAnchor(
              id: 'translation_ai.translation.provider',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.translate),
                title: Text(l10n.translationProvider),
                subtitle: Text(translationLabel),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: pickTranslationProvider,
              ),
            ),
            SettingsTargetAnchor(
              id: 'translation_ai.translation.target_language',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.language),
                title: Text(l10n.targetLanguage),
                subtitle: Text(targetLanguageSubtitle),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: pickTargetLanguage,
              ),
            ),
            SettingsTargetAnchor(
              id: 'translation_ai.translation.prompt',
              controller: targetController,
              child: SettingsTile(
                leading: const Icon(FleurIcons.prompt),
                title: Text(l10n.aiTranslationPrompt),
                subtitle: Text(
                  effectiveAiTranslationPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(FleurIcons.chevronRight),
                onTap: () => unawaited(editAiTranslationPrompt()),
              ),
            ),
            SettingsTile(
              title: Text(l10n.translationProviderBaiduApi),
              subtitle: Text(l10n.translationProviderBaiduApiSubtitle),
              trailing: const Icon(FleurIcons.chevronRight),
              onTap: () => unawaited(configureBaidu()),
            ),
            SettingsTile(
              title: Text(l10n.translationProviderDeepLApi),
              subtitle: Text(
                '${l10n.deepLEndpoint}: ${_deepLEndpointLabel(l10n, settings.deepL.endpoint)} \u00B7 ${l10n.apiKey}',
              ),
              trailing: const Icon(FleurIcons.chevronRight),
              onTap: () => unawaited(configureDeepL()),
            ),
            SettingsTile(
              title: Text(l10n.translationProviderDeepLX),
              subtitle: Text(
                settings.deepLX.baseUrl.trim().isEmpty
                    ? l10n.baseUrl
                    : settings.deepLX.baseUrl.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(FleurIcons.chevronRight),
              onTap: () => unawaited(setDeepLXBaseUrl()),
            ),
          ],
        ),
      ),
    );
  }
}

String _translationProviderLabel(
  AppLocalizations l10n,
  TranslationProviderSelection selection,
  TranslationAiSettings settings,
) {
  return switch (selection.kind) {
    TranslationProviderKind.googleWeb => l10n.translationProviderGoogleWeb,
    TranslationProviderKind.bingWeb => l10n.translationProviderBingWeb,
    TranslationProviderKind.baiduApi => l10n.translationProviderBaiduApi,
    TranslationProviderKind.deepLApi => l10n.translationProviderDeepLApi,
    TranslationProviderKind.deepLX => l10n.translationProviderDeepLX,
    TranslationProviderKind.aiService => _aiServiceTranslationLabel(
      l10n,
      settings,
      selection.aiServiceId,
    ),
  };
}

String _aiServiceTranslationLabel(
  AppLocalizations l10n,
  TranslationAiSettings settings,
  String? serviceId,
) {
  final id = (serviceId ?? '').trim();
  if (id.isEmpty) return l10n.aiService;
  for (final service in settings.aiServices) {
    if (service.id == id) {
      return l10n.translationProviderAiService(service.name);
    }
  }
  return l10n.aiService;
}

String _deepLEndpointLabel(AppLocalizations l10n, DeepLEndpoint endpoint) {
  return switch (endpoint) {
    DeepLEndpoint.free => l10n.deepLEndpointFree,
    DeepLEndpoint.pro => l10n.deepLEndpointPro,
  };
}
