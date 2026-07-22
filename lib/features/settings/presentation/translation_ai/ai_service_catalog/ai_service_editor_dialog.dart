import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/utils/context_extensions.dart';

import 'ai_service_templates.dart';

Future<void> showAiServiceEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  required AiServiceTemplate? template,
  AiServiceConfig? existing,
}) async {
  assert(existing != null || template != null);

  final secrets = ref.read(translationAiSecretStoreProvider);
  final existingKey = existing == null
      ? null
      : await secrets.getAiServiceApiKey(existing.id);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => _AiServiceEditorDialog(
      template: template,
      existing: existing,
      existingKey: existingKey,
    ),
  );
}

class _AiServiceEditorDialog extends ConsumerStatefulWidget {
  const _AiServiceEditorDialog({
    required this.template,
    required this.existing,
    required this.existingKey,
  });

  final AiServiceTemplate? template;
  final AiServiceConfig? existing;
  final String? existingKey;

  @override
  ConsumerState<_AiServiceEditorDialog> createState() =>
      _AiServiceEditorDialogState();
}

class _AiServiceEditorDialogState
    extends ConsumerState<_AiServiceEditorDialog> {
  late final AiServiceApiType _apiType;
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final FocusNode _nameFocus;
  late final FocusNode _baseUrlFocus;
  late final FocusNode _modelFocus;
  late final FocusNode _apiKeyFocus;

  bool _obscure = true;
  bool _submitting = false;
  String? _baseUrlError;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final template = widget.template;
    _apiType = existing?.apiType ?? template!.apiType;
    _nameController = TextEditingController(
      text: existing?.name ?? (template?.name ?? ''),
    );
    _baseUrlController = TextEditingController(
      text: existing?.baseUrl ?? (template?.baseUrl ?? ''),
    );
    _modelController = TextEditingController(
      text: existing?.defaultModel ?? (template?.defaultModel ?? ''),
    );
    _apiKeyController = TextEditingController(text: widget.existingKey ?? '');
    _nameFocus = FocusNode();
    _baseUrlFocus = FocusNode();
    _modelFocus = FocusNode();
    _apiKeyFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _nameFocus.dispose();
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isNotEmpty) {
      final uri = Uri.tryParse(baseUrl);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        setState(() => _baseUrlError = l10n.invalidBaseUrl);
        FocusScope.of(context).requestFocus(_baseUrlFocus);
        return;
      }
    }

    setState(() {
      _baseUrlError = null;
      _submitting = true;
    });
    try {
      final controller = ref.read(translationAiSettingsProvider.notifier);
      final existing = widget.existing;
      if (existing != null) {
        await controller.updateAiService(
          existing.copyWith(
            name: name.isEmpty ? existing.name : name,
            baseUrl: baseUrl,
            defaultModel: model,
          ),
          apiKey: apiKey,
          previousApiKey: widget.existingKey ?? '',
        );
      } else {
        await controller.addAiService(
          name: name.isEmpty ? widget.template!.name : name,
          apiType: _apiType,
          baseUrl: baseUrl,
          defaultModel: model,
          enabled: true,
          apiKey: apiKey,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.w(
        'AI service editor submit failed',
        tag: 'ai_settings',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'operation': _editing ? 'updateAiService' : 'addAiService',
          'serviceId': widget.existing?.id,
          'apiType': _apiType.name,
          'enabled': widget.existing?.enabled ?? true,
        },
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(_editing ? l10n.edit : l10n.add),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(apiTypeIcon(_apiType), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(apiTypeLabel(_apiType))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_baseUrlFocus),
              decoration: InputDecoration(labelText: l10n.fieldName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              focusNode: _baseUrlFocus,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_baseUrlError == null) return;
                setState(() => _baseUrlError = null);
              },
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_modelFocus),
              decoration: InputDecoration(
                labelText: l10n.baseUrl,
                errorText: _baseUrlError,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              focusNode: _modelFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_apiKeyFocus),
              decoration: InputDecoration(labelText: l10n.defaultModel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              focusNode: _apiKeyFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: l10n.apiKey,
                helperText: l10n.savedApiKeyClearHint,
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.show : l10n.hide,
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : () => unawaited(_submit()),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.done),
        ),
      ],
    );
  }
}
