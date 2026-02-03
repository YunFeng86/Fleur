import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';

Future<int?> showAddSubscriptionDialog(
  BuildContext context,
  WidgetRef ref, {
  NavigatorState? navigator,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final nav = navigator ?? Navigator.of(context);

  final controller = TextEditingController();
  final String? url;
  try {
    url = await nav.push<String?>(
      DialogRoute<String?>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        useSafeArea: true,
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
      ),
    );
  } finally {
    controller.dispose();
  }
  if (url == null || url.trim().isEmpty) return null;

  final id = await ref.read(feedRepositoryProvider).upsertUrl(url);
  final r = await ref.read(syncServiceProvider).refreshFeedSafe(id);
  if (!context.mounted) return id;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        r.ok ? l10n.addedAndSynced : l10n.errorMessage(r.error.toString()),
      ),
    ),
  );
  return id;
}
