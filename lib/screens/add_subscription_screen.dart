import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../l10n/app_localizations.dart';
import '../models/article_scope.dart';
import '../theme/fleur_icons.dart';
import '../ui/actions/subscription_actions.dart';

class AddSubscriptionScreen extends ConsumerWidget {
  const AddSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addSubscription)),
      body: Center(
        child: FilledButton.icon(
          onPressed: () async {
            final id = await SubscriptionActions.addFeed(context, ref);
            if (id == null || !context.mounted) return;
            SubscriptionActions.selectFeed(ref, id);
            context.go(scopeLocation(ArticleScope.feed(id)));
          },
          icon: const Icon(FleurIcons.add),
          label: Text(l10n.addSubscription),
        ),
      ),
    );
  }
}
