import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/translation_ai_settings_providers.dart';
import '../../../services/settings/translation_ai_settings.dart';
import '../../../utils/context_extensions.dart';
import 'ai_service_templates.dart';

Future<void> showAiServiceEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  required AiServiceTemplate? template,
  AiServiceConfig? existing,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final secrets = ref.read(translationAiSecretStoreProvider);

  final editing = existing != null;
  final apiType = existing?.apiType ?? template!.apiType;
  final initialName = existing?.name ?? (template?.name ?? '');
  final initialBaseUrl = existing?.baseUrl ?? (template?.baseUrl ?? '');
  final initialModel = existing?.defaultModel ?? (template?.defaultModel ?? '');

  final existingKey = editing
      ? await secrets.getAiServiceApiKey(existing.id)
      : null;
  if (!context.mounted) return;

  final nameCtrl = TextEditingController(text: initialName);
  final baseUrlCtrl = TextEditingController(text: initialBaseUrl);
  final modelCtrl = TextEditingController(text: initialModel);

  final apiKeyCtrl = TextEditingController(text: existingKey ?? '');
  final nameFocus = FocusNode();
  final baseUrlFocus = FocusNode();
  final modelFocus = FocusNode();
  final apiKeyFocus = FocusNode();
  var obscure = true;
  var submitting = false;
  String? baseUrlError;

  Future<void> submit(StateSetter setState, BuildContext dialogContext) async {
    if (submitting) return;
    final name = nameCtrl.text.trim();
    final baseUrl = baseUrlCtrl.text.trim();
    final model = modelCtrl.text.trim();
    final apiKey = apiKeyCtrl.text.trim();
    String? nextBaseUrlError;

    if (baseUrl.isNotEmpty) {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        nextBaseUrlError = l10n.invalidBaseUrl;
      }
    }
    if (nextBaseUrlError != null) {
      setState(() => baseUrlError = nextBaseUrlError);
      FocusScope.of(dialogContext).requestFocus(baseUrlFocus);
      return;
    }

    setState(() {
      baseUrlError = null;
      submitting = true;
    });
    try {
      final controller = ref.read(translationAiSettingsProvider.notifier);
      if (editing) {
        final updated = existing.copyWith(
          name: name.isEmpty ? existing.name : name,
          baseUrl: baseUrl,
          defaultModel: model,
        );
        await controller.updateAiService(
          updated,
          apiKey: apiKey,
          previousApiKey: existingKey ?? '',
        );
      } else {
        await controller.addAiService(
          name: name.isEmpty ? template!.name : name,
          apiType: apiType,
          baseUrl: baseUrl,
          defaultModel: model,
          enabled: true,
          apiKey: apiKey,
        );
      }
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    } catch (e) {
      if (!dialogContext.mounted) return;
      setState(() => submitting = false);
      dialogContext.showError(e);
    }
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(editing ? l10n.edit : l10n.add),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(apiTypeIcon(apiType), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(apiTypeLabel(apiType))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(baseUrlFocus),
                      decoration: InputDecoration(labelText: l10n.fieldName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlCtrl,
                      focusNode: baseUrlFocus,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (baseUrlError == null) return;
                        setState(() => baseUrlError = null);
                      },
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).requestFocus(modelFocus),
                      decoration: InputDecoration(
                        labelText: l10n.baseUrl,
                        errorText: baseUrlError,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelCtrl,
                      focusNode: modelFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(
                        dialogContext,
                      ).requestFocus(apiKeyFocus),
                      decoration: InputDecoration(labelText: l10n.defaultModel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKeyCtrl,
                      focusNode: apiKeyFocus,
                      obscureText: obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          unawaited(submit(setState, dialogContext)),
                      decoration: InputDecoration(
                        labelText: l10n.apiKey,
                        helperText: l10n.savedApiKeyClearHint,
                        suffixIcon: IconButton(
                          tooltip: obscure ? l10n.show : l10n.hide,
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
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
  } finally {
    nameCtrl.dispose();
    baseUrlCtrl.dispose();
    modelCtrl.dispose();
    apiKeyCtrl.dispose();
    nameFocus.dispose();
    baseUrlFocus.dispose();
    modelFocus.dispose();
    apiKeyFocus.dispose();
  }
}
