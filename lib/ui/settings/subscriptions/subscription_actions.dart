import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers/app_settings_providers.dart';
import '../../../../providers/opml_providers.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../../../services/opml/opml_service.dart';

class SubscriptionActions {
  static Future<void> showAddFeedDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addSubscription),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.rssAtomUrl,
              hintText: 'https://example.com/feed.xml',
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
    if (url == null || url.trim().isEmpty) return;

    final id = await ref.read(feedRepositoryProvider).upsertUrl(url);
    final r = await ref.read(syncServiceProvider).refreshFeedSafe(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok ? l10n.addedAndSynced : l10n.errorMessage(r.error.toString()),
        ),
      ),
    );
  }

  static Future<void> showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.newCategory),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(categoryRepositoryProvider).upsertByName(name);
  }

  static Future<void> refreshFeed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final r = await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok ? l10n.refreshed : l10n.errorMessage(r.error.toString()),
        ),
      ),
    );
  }

  static Future<void> refreshAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    if (feeds.isEmpty) return;

    final appSettings = ref.read(appSettingsProvider).valueOrNull;
    final concurrency = appSettings?.autoRefreshConcurrency ?? 2;

    if (!context.mounted) return;

    // Show progress dialog
    final progressNotifier = ValueNotifier<String>('0/${feeds.length}');
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (context, value, _) {
                      return Text(
                        l10n.refreshingProgress(
                          int.tryParse(value.split('/')[0]) ?? 0,
                          int.tryParse(value.split('/')[1]) ?? feeds.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ).then((_) {}),
    );

    final batch = await ref
        .read(syncServiceProvider)
        .refreshFeedsSafe(
          feeds.map((f) => f.id),
          maxConcurrent: concurrency,
          onProgress: (current, total) {
            progressNotifier.value = '$current/$total';
          },
        );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close progress dialog

    final err = batch.firstError?.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
        ),
      ),
    );
  }

  static Future<void> moveFeedToCategory(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;

    // Returns -1 for Uncategorized, categoryId for category, null for Cancel.
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.moveToCategory),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(-1),
              child: Text(l10n.uncategorized),
            ),
            for (final c in cats)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(c.id),
                child: Text(c.name),
              ),
          ],
        );
      },
    );

    if (selected == null) return;

    final categoryId = selected == -1 ? null : selected;
    await ref
        .read(feedRepositoryProvider)
        .setCategory(feedId: feedId, categoryId: categoryId);
  }

  static Future<bool> deleteFeed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteSubscriptionConfirmTitle),
          content: Text(l10n.deleteSubscriptionConfirmContent),
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
    if (confirmed != true) return false;
    await ref.read(feedRepositoryProvider).delete(feedId);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.deleted)));
    return true;
  }

  static Future<bool> deleteCategory(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCategoryConfirmTitle),
          content: Text(l10n.deleteCategoryConfirmContent),
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
    if (confirmed != true) return false;
    await ref.read(categoryRepositoryProvider).delete(categoryId);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.categoryDeleted)));
    return true;
  }

  static Future<void> renameCategory(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    required String currentName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    final next = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.rename),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
    if (next == null) return;
    try {
      await ref.read(categoryRepositoryProvider).rename(categoryId, next);
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().contains('already exists')
          ? l10n.nameAlreadyExists
          : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorMessage(msg))));
    }
  }

  // Edit Feed Title
  static Future<void> editFeedTitle(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    required String? currentTitle,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle ?? '');
    final next = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.edit),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            // The original had a "Delete" button inside the Edit dialog.
            // I think distinct actions are better in 3-pane.
            // But if user wants, we can keep it?
            // I will remove the "Delete" button from here as we have a dedicated Delete action in the panel.
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
    if (next == null) return;
    await ref
        .read(feedRepositoryProvider)
        .setUserTitle(feedId: feedId, userTitle: next);
  }

  static Future<void> importOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    const group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final xml = await file.readAsString();
    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMessage(l10n.opmlParseFailed))),
      );
      return;
    }
    if (entries.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noFeedsFoundInOpml)));
      return;
    }

    var added = 0;
    for (final e in entries) {
      final feedId = await ref.read(feedRepositoryProvider).upsertUrl(e.url);
      if (e.category != null && e.category!.trim().isNotEmpty) {
        final catId = await ref
            .read(categoryRepositoryProvider)
            .upsertByName(e.category!);
        await ref
            .read(feedRepositoryProvider)
            .setCategory(feedId: feedId, categoryId: catId);
      }
      added += 1;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importedFeeds(added))));
  }

  static Future<void> exportOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final loc = await getSaveLocation(suggestedName: 'subscriptions.opml');
    if (loc == null) return;
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    final names = {for (final c in cats) c.id: c.name};
    final xml = ref
        .read(opmlServiceProvider)
        .buildOpml(feeds: feeds, categoryNames: names);
    final xfile = XFile.fromData(
      Uint8List.fromList(utf8.encode(xml)),
      mimeType: 'text/xml',
      name: 'subscriptions.opml',
    );
    await xfile.saveTo(loc.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportedOpml)));
  }

  static Future<void> updateFeedSettings(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
  }) async {
    await ref
        .read(feedRepositoryProvider)
        .updateSettings(
          id: feedId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
        );
  }

  static Future<void> updateCategorySettings(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .updateSettings(
          id: categoryId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
        );
  }
}
