import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/logging/app_logger.dart';
import '../../services/update/app_update_manifest.dart';
import '../../theme/fleur_icons.dart';
import '../../utils/context_extensions.dart';
import '../../widgets/app_scrollbar.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateManifest manifest,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AppUpdateDialog(manifest: manifest),
  );
}

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({super.key, required this.manifest});

  final AppUpdateManifest manifest;

  Future<void> _openReleasePage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final opened = await launchUrl(
        manifest.releaseUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        context.showErrorMessage(l10n.openFailedGeneral);
      }
    } catch (e, s) {
      AppLogger.w(
        'Open update release page failed',
        tag: 'update',
        error: e,
        stackTrace: s,
      );
      if (context.mounted) context.showErrorMessage(l10n.openFailedGeneral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final notes = manifest.notesForLocale(locale);

    return AlertDialog(
      title: Text(l10n.newVersionAvailable(manifest.version)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.releaseNotes,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: AppScrollbar(
                child: SingleChildScrollView(
                  child: SelectableText(
                    notes,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_openReleasePage(context));
          },
          icon: const Icon(FleurIcons.openExternal),
          label: Text(l10n.goToOfficialUpdate),
        ),
      ],
    );
  }
}
