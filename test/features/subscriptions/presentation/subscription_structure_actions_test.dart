import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/subscriptions/presentation/subscription_structure_actions.dart';
import 'package:fleur/l10n/app_localizations.dart';

void main() {
  testWidgets('edit-feed-title dialog exposes a delete action', (tester) async {
    final controller = TextEditingController(text: 'Custom title');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return SubscriptionStructureActions.buildEditFeedTitleDialog(
              context,
              l10n: AppLocalizations.of(context)!,
              controller: controller,
            );
          },
        ),
      ),
    );

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('edit-feed-title delete action closes with an empty result', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Custom title');
    addTearDown(controller.dispose);
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_edit_feed_title_dialog'),
                  onPressed: () async {
                    result = await showDialog<String?>(
                      context: context,
                      builder: (dialogContext) {
                        return SubscriptionStructureActions.buildEditFeedTitleDialog(
                          dialogContext,
                          l10n: l10n,
                          controller: controller,
                        );
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_edit_feed_title_dialog')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(result, '');
  });
}
