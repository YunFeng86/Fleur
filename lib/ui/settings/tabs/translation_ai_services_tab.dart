import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/translation_ai_settings_providers.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/settings/translation_ai_settings.dart';
import '../../../theme/fleur_icons.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/language_utils.dart';
import '../../../utils/prompt_template.dart';
import '../../../widgets/app_scrollbar.dart';
import '../../app_menu.dart';
import '../../dialogs/side_panel.dart';
import '../../dialogs/text_input_dialog.dart';
import '../translation_ai/ai_service_editor_dialog.dart';
import '../translation_ai/ai_service_templates.dart';
import '../settings_targets.dart';
import '../widgets/section_header.dart';

enum _AiServiceAction { setDefault, edit, delete }

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
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (settings) {
        final enabledServices = settings.aiServices
            .where((s) => s.enabled)
            .toList(growable: false);

        Future<void> pickTranslationProvider() async {
          final picked =
              await showModalBottomSheet<TranslationProviderSelection>(
                context: context,
                showDragHandle: true,
                builder: (context) {
                  final current = settings.translationProvider;
                  final options = <TranslationProviderSelection>[
                    const TranslationProviderSelection.googleWeb(),
                    const TranslationProviderSelection.bingWeb(),
                    const TranslationProviderSelection.baiduApi(),
                    const TranslationProviderSelection.deepLApi(),
                    const TranslationProviderSelection.deepLX(),
                    ...enabledServices.map(
                      (s) => TranslationProviderSelection.aiService(s.id),
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
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          for (final option in options)
                            ListTile(
                              title: Text(
                                _translationProviderLabel(
                                  l10n,
                                  option,
                                  settings,
                                ),
                              ),
                              trailing: option == current
                                  ? const Icon(FleurIcons.check)
                                  : null,
                              onTap: () => Navigator.of(context).pop(option),
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
            if (uri == null ||
                !(uri.scheme == 'http' || uri.scheme == 'https')) {
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

          final apiKeyCtrl = TextEditingController(text: existingKey ?? '');
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
              final key = apiKeyCtrl.text.trim();
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
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => submitting = false);
              dialogContext.showError(e);
            }
          }

          await showDialog<void>(
            context: context,
            builder: (context) {
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
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(l10n.deepLEndpointFree),
                                selected: endpoint == DeepLEndpoint.free,
                                onSelected: (v) {
                                  if (!v) return;
                                  setState(() => endpoint = DeepLEndpoint.free);
                                },
                              ),
                              ChoiceChip(
                                label: Text(l10n.deepLEndpointPro),
                                selected: endpoint == DeepLEndpoint.pro,
                                onSelected: (v) {
                                  if (!v) return;
                                  setState(() => endpoint = DeepLEndpoint.pro);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: apiKeyCtrl,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: l10n.apiKey,
                              suffixIcon: IconButton(
                                tooltip: obscure ? l10n.show : l10n.hide,
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.savedApiKeyClearHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

          final appIdCtrl = TextEditingController(text: existing?.appId ?? '');
          final appKeyCtrl = TextEditingController(
            text: existing?.appKey ?? '',
          );
          var obscure = true;
          var submitting = false;

          Future<void> submit(
            StateSetter setState,
            BuildContext dialogContext,
          ) async {
            if (submitting) return;
            final id = appIdCtrl.text.trim();
            final key = appKeyCtrl.text;

            setState(() => submitting = true);
            try {
              if (id.isEmpty || key.isEmpty) {
                await secrets.deleteBaiduCredentials();
              } else {
                await secrets.setBaiduCredentials(appId: id, appKey: key);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => submitting = false);
              dialogContext.showError(e);
            }
          }

          await showDialog<void>(
            context: context,
            builder: (context) {
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
                            controller: appIdCtrl,
                            decoration: InputDecoration(labelText: l10n.appId),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: appKeyCtrl,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: l10n.appKey,
                              suffixIcon: IconButton(
                                tooltip: obscure ? l10n.show : l10n.hide,
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.savedCredentialsClearHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

        Future<void> addAiService() async {
          final picked = await showSidePanel<AiServiceTemplate>(
            context,
            builder: (context) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(l10n.addAiService),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(FleurIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                body: AppScrollbar(
                  child: ListView(
                    children: [
                      for (final t in aiServiceTemplates)
                        ListTile(
                          leading: Icon(apiTypeIcon(t.apiType)),
                          title: Text(t.name),
                          subtitle: Text(apiTypeLabel(t.apiType)),
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
          if (picked == null) return;
          if (!context.mounted) return;
          await showAiServiceEditorDialog(context, ref, template: picked);
        }

        Future<void> editAiService(AiServiceConfig service) async {
          await showAiServiceEditorDialog(
            context,
            ref,
            template: null,
            existing: service,
          );
        }

        Future<void> confirmDeleteAiService(AiServiceConfig service) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(l10n.delete),
                content: Text('${l10n.delete} "${service.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.delete),
                  ),
                ],
              );
            },
          );
          if (ok != true) return;
          await ref
              .read(translationAiSettingsProvider.notifier)
              .deleteAiService(service.id);
          if (!context.mounted) return;
          context.showSuccess(l10n.done);
        }

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
            ? '${l10n.followAppLanguage} · ${localizedLanguageNameForTag(uiLocale, followAppTargetLanguageTag)}'
            : localizedLanguageNameForTag(uiLocale, effectiveTargetLanguageTag);

        final defaultAiSummaryPromptTemplate = l10n
            .defaultAiSummaryPromptTemplate(
              PromptTemplate.token(PromptTemplate.varLanguage),
              PromptTemplate.token(PromptTemplate.varTitle),
              PromptTemplate.token(PromptTemplate.varContent),
            );
        final defaultAiTranslationPromptTemplate = l10n
            .defaultAiTranslationPromptTemplate(
              PromptTemplate.token(PromptTemplate.varLanguage),
              PromptTemplate.token(PromptTemplate.varTitle),
              PromptTemplate.token(PromptTemplate.varContent),
            );

        final effectiveAiSummaryPrompt =
            ((settings.aiSummaryPrompt ?? defaultAiSummaryPromptTemplate)
                .trim());
        final effectiveAiTranslationPrompt =
            ((settings.aiTranslationPrompt ??
                    defaultAiTranslationPromptTemplate)
                .trim());

        String? serviceNameById(String serviceId) {
          return settings.aiServices
              .where((s) => s.id == serviceId)
              .firstOrNull
              ?.name;
        }

        final defaultAiServiceId = settings.defaultAiServiceId;
        final defaultAiServiceName = defaultAiServiceId == null
            ? null
            : (serviceNameById(defaultAiServiceId) ?? defaultAiServiceId);

        final explicitAiSummaryServiceId = settings.aiSummaryServiceId;
        final effectiveAiSummaryServiceId =
            explicitAiSummaryServiceId ?? defaultAiServiceId;
        final effectiveAiSummaryServiceName =
            effectiveAiSummaryServiceId == null
            ? null
            : (serviceNameById(effectiveAiSummaryServiceId) ??
                  effectiveAiSummaryServiceId);

        final aiSummaryServiceSubtitle = effectiveAiSummaryServiceName == null
            ? l10n.aiNotConfigured
            : (explicitAiSummaryServiceId == null
                  ? '${l10n.defaultOption} · $effectiveAiSummaryServiceName'
                  : effectiveAiSummaryServiceName);

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
                builder: (context) {
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
                              style: Theme.of(context).textTheme.titleMedium,
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
                              context,
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
                                context,
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

        Future<void> pickAiSummaryService() async {
          final enabled = settings.aiServices
              .where((s) => s.enabled)
              .toList(growable: false);

          final picked =
              await showModalBottomSheet<({bool isDefault, String? value})>(
                context: context,
                showDragHandle: true,
                builder: (context) {
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
                              style: Theme.of(context).textTheme.titleMedium,
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
                              context,
                            ).pop(const (isDefault: true, value: null)),
                          ),
                          for (final s in enabled)
                            ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(s.name)),
                                  if (s.id == defaultAiServiceId)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        FleurIcons.starActive,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(apiTypeLabel(s.apiType)),
                              trailing: explicitAiSummaryServiceId == s.id
                                  ? const Icon(FleurIcons.check)
                                  : null,
                              onTap: () => Navigator.of(
                                context,
                              ).pop((isDefault: false, value: s.id)),
                            ),
                          if (enabled.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                l10n.aiNotConfigured,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ListTile(
                            leading: const Icon(FleurIcons.add),
                            title: Text(l10n.addAiService),
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(addAiService());
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

        Future<void> editPromptTemplate({
          required String title,
          required String? customPrompt,
          required String defaultTemplate,
          required Future<void> Function(String? next) onSave,
        }) async {
          final result = await showDialog<({bool reset, String? value})>(
            context: context,
            builder: (context) {
              final controller = TextEditingController(
                text: customPrompt ?? '',
              );
              return AlertDialog(
                scrollable: true,
                title: Text(title),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.multiline,
                        maxLines: 10,
                        minLines: 6,
                        decoration: InputDecoration(
                          labelText: title,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.defaultOption,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        defaultTemplate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.promptVariables,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        '${PromptTemplate.token(PromptTemplate.varContent)} — ${l10n.promptVariableContentDescription}',
                      ),
                      SelectableText(
                        '${PromptTemplate.token(PromptTemplate.varLanguage)} — ${l10n.promptVariableLanguageDescription}',
                      ),
                      SelectableText(
                        '${PromptTemplate.token(PromptTemplate.varTitle)} — ${l10n.promptVariableTitleDescription}',
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const (reset: true, value: null)),
                    child: Text(l10n.resetToDefault),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((reset: false, value: controller.text)),
                    child: Text(l10n.done),
                  ),
                ],
              );
            },
          );
          if (result == null) return;

          if (result.reset) {
            await onSave(null);
          } else {
            final trimmed = (result.value ?? '').trim();
            final defaultTrimmed = defaultTemplate.trim();
            await onSave(
              trimmed.isEmpty || trimmed == defaultTrimmed ? null : trimmed,
            );
          }

          if (!context.mounted) return;
          context.showSuccess(l10n.done);
        }

        Future<void> editAiSummaryPrompt() async {
          await editPromptTemplate(
            title: l10n.aiSummaryPrompt,
            customPrompt: settings.aiSummaryPrompt,
            defaultTemplate: defaultAiSummaryPromptTemplate,
            onSave: (next) => ref
                .read(translationAiSettingsProvider.notifier)
                .setAiSummaryPrompt(next),
          );
        }

        Future<void> editAiTranslationPrompt() async {
          await editPromptTemplate(
            title: l10n.aiTranslationPrompt,
            customPrompt: settings.aiTranslationPrompt,
            defaultTemplate: defaultAiTranslationPromptTemplate,
            onSave: (next) => ref
                .read(translationAiSettingsProvider.notifier)
                .setAiTranslationPrompt(next),
          );
        }

        Future<void> editTpmLimit() async {
          final picked = await showDialog<int>(
            context: context,
            builder: (context) {
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(labelText: l10n.tpmLimit),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final raw = controller.text.trim();
                      final v = int.tryParse(raw);
                      Navigator.of(context).pop(v ?? 0);
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

        return SettingsPageBody(
          children: [
            if (showPageTitle) ...[
              SectionHeader(title: l10n.translationAndAiServices),
              const SizedBox(height: 8),
            ],
            SettingsSection(
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
                        onTap: editAiTranslationPrompt,
                      ),
                    ),
                    SettingsTile(
                      title: Text(l10n.translationProviderBaiduApi),
                      subtitle: Text(l10n.translationProviderBaiduApiSubtitle),
                      trailing: const Icon(FleurIcons.chevronRight),
                      onTap: configureBaidu,
                    ),
                    SettingsTile(
                      title: Text(l10n.translationProviderDeepLApi),
                      subtitle: Text(
                        '${l10n.deepLEndpoint}: ${_deepLEndpointLabel(l10n, settings.deepL.endpoint)} · ${l10n.apiKey}',
                      ),
                      trailing: const Icon(FleurIcons.chevronRight),
                      onTap: configureDeepL,
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
                      onTap: setDeepLXBaseUrl,
                    ),
                  ],
                ),
              ),
            ),
            SettingsSection(
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
                        onTap: pickAiSummaryService,
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
                        onTap: editAiSummaryPrompt,
                      ),
                    ),
                    SettingsTargetAnchor(
                      id: 'translation_ai.summary.tpm_limit',
                      controller: targetController,
                      child: SettingsTile(
                        leading: const Icon(FleurIcons.speed),
                        title: Text(l10n.tpmLimit),
                        subtitle: Text(
                          '${settings.tpmLimit} · ${l10n.tpmLimitSubtitle}',
                        ),
                        trailing: const Icon(FleurIcons.chevronRight),
                        onTap: editTpmLimit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SettingsSection(
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
                        onPressed: addAiService,
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
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final s = settings.aiServices[index];
                              final isDefault =
                                  s.id == settings.defaultAiServiceId;
                              final theme = Theme.of(context);
                              final subtitleText = [
                                apiTypeLabel(s.apiType),
                                if (s.baseUrl.trim().isNotEmpty)
                                  s.baseUrl.trim(),
                                if (s.defaultModel.trim().isNotEmpty)
                                  l10n.modelSummary(s.defaultModel.trim()),
                              ].join(' · ');

                              Future<void> handleAction(
                                _AiServiceAction action,
                              ) async {
                                switch (action) {
                                  case _AiServiceAction.setDefault:
                                    await ref
                                        .read(
                                          translationAiSettingsProvider
                                              .notifier,
                                        )
                                        .setDefaultAiService(s.id);
                                    if (!context.mounted) return;
                                    context.showSuccess(l10n.done);
                                    return;
                                  case _AiServiceAction.edit:
                                    await editAiService(s);
                                    return;
                                  case _AiServiceAction.delete:
                                    await confirmDeleteAiService(s);
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
                                      label: isDefault
                                          ? l10n.defaultAlreadySet
                                          : l10n.setAsDefault,
                                    ),
                                    AppMenuItem(
                                      value: _AiServiceAction.edit,
                                      label: l10n.edit,
                                    ),
                                    AppMenuItem(
                                      value: _AiServiceAction.delete,
                                      label: l10n.delete,
                                      destructive: true,
                                    ),
                                  ],
                                  onSelected: (action) {
                                    unawaited(handleAction(action));
                                  },
                                );
                              }

                              Widget buildToggle({bool showLabel = false}) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showLabel) ...[
                                      Text(
                                        s.enabled ? l10n.enabled : l10n.off,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Switch.adaptive(
                                      value: s.enabled,
                                      onChanged: (v) => ref
                                          .read(
                                            translationAiSettingsProvider
                                                .notifier,
                                          )
                                          .setAiServiceEnabled(s.id, v),
                                    ),
                                  ],
                                );
                              }

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final useCompactActions =
                                      constraints.maxWidth < 560;

                                  if (useCompactActions) {
                                    return InkWell(
                                      onTap: () => unawaited(editAiService(s)),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          12,
                                          8,
                                          12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Icon(
                                                apiTypeIcon(s.apiType),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          s.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isDefault)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                left: 8,
                                                              ),
                                                          child: Icon(
                                                            FleurIcons
                                                                .starActive,
                                                            size: 18,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    subtitleText,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 8,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        s.enabled
                                                            ? l10n.enabled
                                                            : l10n.off,
                                                        style: theme
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                      Switch.adaptive(
                                                        value: s.enabled,
                                                        onChanged: (v) => ref
                                                            .read(
                                                              translationAiSettingsProvider
                                                                  .notifier,
                                                            )
                                                            .setAiServiceEnabled(
                                                              s.id,
                                                              v,
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
                                    leading: Icon(apiTypeIcon(s.apiType)),
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(s.name)),
                                        if (isDefault)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              FleurIcons.starActive,
                                              size: 18,
                                            ),
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
                                      children: [
                                        buildToggle(),
                                        buildMenuButton(),
                                      ],
                                    ),
                                    onTap: () => unawaited(editAiService(s)),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
  for (final s in settings.aiServices) {
    if (s.id == id) return l10n.translationProviderAiService(s.name);
  }
  return l10n.aiService;
}

String _deepLEndpointLabel(AppLocalizations l10n, DeepLEndpoint endpoint) {
  return switch (endpoint) {
    DeepLEndpoint.free => l10n.deepLEndpointFree,
    DeepLEndpoint.pro => l10n.deepLEndpointPro,
  };
}
