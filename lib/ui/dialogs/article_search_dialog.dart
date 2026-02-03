import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/query_providers.dart';
import '../../services/settings/app_settings.dart';

Future<void> showArticleSearchDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final appSettings =
      ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
  final initialQuery = ref.read(articleSearchQueryProvider);

  final result = await showDialog<({String query, bool searchInContent})>(
    context: context,
    builder: (context) => _ArticleSearchDialog(
      title: l10n.search,
      hintText: l10n.search,
      searchInContentLabel: l10n.searchInContent,
      cancelLabel: l10n.cancel,
      deleteLabel: l10n.delete,
      doneLabel: l10n.done,
      initialQuery: initialQuery,
      initialSearchInContent: appSettings.searchInContent,
    ),
  );
  if (result == null) return;

  await ref
      .read(appSettingsProvider.notifier)
      .setSearchInContent(result.searchInContent);
  ref.read(articleSearchQueryProvider.notifier).state = result.query.trim();
}

class _ArticleSearchDialog extends StatefulWidget {
  const _ArticleSearchDialog({
    required this.title,
    required this.hintText,
    required this.searchInContentLabel,
    required this.cancelLabel,
    required this.deleteLabel,
    required this.doneLabel,
    required this.initialQuery,
    required this.initialSearchInContent,
  });

  final String title;
  final String hintText;
  final String searchInContentLabel;
  final String cancelLabel;
  final String deleteLabel;
  final String doneLabel;

  final String initialQuery;
  final bool initialSearchInContent;

  @override
  State<_ArticleSearchDialog> createState() => _ArticleSearchDialogState();
}

class _ArticleSearchDialogState extends State<_ArticleSearchDialog> {
  late final TextEditingController _controller;
  late bool _searchInContent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _searchInContent = widget.initialSearchInContent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _popWithQuery(String query) {
    Navigator.of(
      context,
    ).pop((query: query, searchInContent: _searchInContent));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(hintText: widget.hintText),
              onSubmitted: _popWithQuery,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.searchInContentLabel),
              value: _searchInContent,
              onChanged: (v) => setState(() => _searchInContent = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => _popWithQuery(''),
          child: Text(widget.deleteLabel),
        ),
        FilledButton(
          onPressed: () => _popWithQuery(_controller.text),
          child: Text(widget.doneLabel),
        ),
      ],
    );
  }
}
