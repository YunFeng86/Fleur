import 'package:flutter/material.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/utils/context_extensions.dart';
import 'package:fleur/utils/prompt_template.dart';

/// Edits one prompt template and normalizes an unchanged custom value to null.
Future<void> showPromptTemplateEditorDialog(
  BuildContext context, {
  required String title,
  required String? customPrompt,
  required String defaultTemplate,
  required Future<void> Function(String? next) onSave,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: customPrompt ?? '');

  final result = await showDialog<({bool reset, String? value})>(
    context: context,
    builder: (dialogContext) {
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
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                defaultTemplate,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.promptVariables,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                '${PromptTemplate.token(PromptTemplate.varContent)} \u2014 ${l10n.promptVariableContentDescription}',
              ),
              SelectableText(
                '${PromptTemplate.token(PromptTemplate.varLanguage)} \u2014 ${l10n.promptVariableLanguageDescription}',
              ),
              SelectableText(
                '${PromptTemplate.token(PromptTemplate.varTitle)} \u2014 ${l10n.promptVariableTitleDescription}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(const (reset: true, value: null)),
            child: Text(l10n.resetToDefault),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
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
    await onSave(trimmed.isEmpty || trimmed == defaultTrimmed ? null : trimmed);
  }

  if (!context.mounted) return;
  context.showSuccess(l10n.done);
}
