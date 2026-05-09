import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/settings/subscriptions/subscription_toolbar.dart';
import 'package:fleur/utils/platform.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

void main() {
  testWidgets('SubscriptionToolbar does not overflow on macOS medium width', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;

    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    tester.view.physicalSize = const Size(836, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SubscriptionToolbar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      debugFleurTargetPlatformOverride = null;
    }
  });

  testWidgets('Fever toolbar hides category and import actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.fever),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionToolbar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('New category'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Import OPML'), findsNothing);
    expect(find.text('Export OPML'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);
    expect(find.text('Refresh sources'), findsNothing);
  });

  testWidgets('Local toolbar uses Refresh sources wording', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.local),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionToolbar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Refresh sources'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);
  });

  testWidgets('Miniflux toolbar uses Refresh sources wording', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionToolbar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Refresh sources'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);
  });
}
