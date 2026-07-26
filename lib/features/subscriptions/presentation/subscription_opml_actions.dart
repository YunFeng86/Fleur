import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../application/opml_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../services/opml/opml_service.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/platform.dart';
import 'subscription_remote_feedback.dart' as remote_feedback;

class SubscriptionOpmlActions {
  const SubscriptionOpmlActions._();

  static Future<void> importOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (!ref
        .read(backendCapabilitiesProvider)
        .isVisible(BackendFeature.importOpml)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
      // Some iPadOS providers classify OPML as generic data.
      uniformTypeIdentifiers: isIOS
          ? ['public.xml', 'public.text', 'public.data']
          : ['public.xml'],
    );

    XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: [group]);
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'importOpml.openFile',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(error.toString()));
      return;
    }
    if (file == null) return;

    final nameOrPath = file.name.isNotEmpty ? file.name : file.path;
    final dot = nameOrPath.lastIndexOf('.');
    final extension = dot == -1 ? '' : nameOrPath.substring(dot).toLowerCase();
    if (extension.isNotEmpty && extension != '.opml' && extension != '.xml') {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.opmlParseFailed));
      return;
    }

    String xml;
    try {
      xml = await file.readAsString();
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'importOpml.readFile',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(error.toString()));
      return;
    }

    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'importOpml.parse',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.opmlParseFailed));
      return;
    }
    if (entries.isEmpty) {
      if (!context.mounted) return;
      context.showSnack(l10n.noFeedsFoundInOpml);
      return;
    }

    var added = 0;
    for (final entry in entries) {
      final feedId = await ref
          .read(feedRepositoryProvider)
          .upsertUrl(entry.url);
      final category = entry.category;
      if (category != null && category.trim().isNotEmpty) {
        final categoryId = await ref
            .read(categoryRepositoryProvider)
            .upsertByName(category);
        await ref
            .read(feedRepositoryProvider)
            .setCategory(feedId: feedId, categoryId: categoryId);
      }
      added += 1;
    }
    if (!context.mounted) return;
    context.showSnack(l10n.importedFeeds(added));
  }

  static Future<void> exportOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (!ref
        .read(backendCapabilitiesProvider)
        .isVisible(BackendFeature.exportOpml)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final feeds = await ref.read(feedRepositoryProvider).getAll();
    if (feeds.isEmpty) return;

    final categories = await ref.read(categoryRepositoryProvider).getAll();
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final xml = ref
        .read(opmlServiceProvider)
        .buildOpml(feeds: feeds, categoryNames: categoryNames);
    final bytes = Uint8List.fromList(utf8.encode(xml));

    // file_selector_ios has no save dialog, so use the system share sheet.
    if (isIOS) {
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'text/xml',
        name: 'subscriptions.opml',
      );
      final temporaryDirectory = await getTemporaryDirectory();
      final temporaryPath = '${temporaryDirectory.path}/subscriptions.opml';
      try {
        await xfile.saveTo(temporaryPath);
        await IosShareBridge.shareFile(
          path: temporaryPath,
          mimeType: 'text/xml',
          name: 'subscriptions.opml',
        );
      } catch (error, stackTrace) {
        remote_feedback.logSubscriptionFailure(
          ref,
          'exportOpml.share',
          error,
          stackTrace,
        );
        if (!context.mounted) return;
        context.showErrorMessage(l10n.errorMessage(error.toString()));
        return;
      }
      if (!context.mounted) return;
      context.showSnack(l10n.exportedOpml);
      return;
    }

    const group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
      uniformTypeIdentifiers: ['public.xml'],
    );

    FileSaveLocation? location;
    try {
      location = await getSaveLocation(
        suggestedName: 'subscriptions.opml',
        acceptedTypeGroups: [group],
      );
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'exportOpml.pickPath',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(error.toString()));
      return;
    }
    if (location == null) return;

    final file = XFile.fromData(
      bytes,
      mimeType: 'text/xml',
      name: location.path,
    );
    try {
      await file.saveTo(location.path);
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'exportOpml.saveFile',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(error.toString()));
      return;
    }
    if (!context.mounted) return;
    context.showSnack(l10n.exportedOpml);
  }
}
