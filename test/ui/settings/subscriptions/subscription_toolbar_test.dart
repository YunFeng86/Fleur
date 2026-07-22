import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/refresh_all_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/refresh_all_coordinator.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/settings/subscriptions/subscription_toolbar.dart';
import 'package:fleur/utils/platform.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  @override
  Future<List<Feed>> getAll() async {
    return [
      Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Feed',
    ];
  }
}

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

  testWidgets('Fever toolbar syncs account and hides source actions', (
    tester,
  ) async {
    final account = buildTestAccount(type: AccountType.fever);
    final syncService = FakeSyncService();
    final capabilities = BackendCapabilities.forAccountType(account.type);
    final feeds = _FakeFeedRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(account),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          scopedRefreshCoordinatorProvider.overrideWithValue(
            ScopedRefreshCoordinator(
              capabilities: capabilities,
              feeds: feeds,
              syncService: syncService,
              refreshSources: RefreshSourcesCoordinator(
                capabilities: capabilities,
                feeds: feeds,
                syncService: syncService,
              ),
            ),
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

    await tester.tap(find.byIcon(FleurIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Import OPML'), findsNothing);
    expect(find.text('Export OPML'), findsOneWidget);
    expect(find.text('Sync account'), findsOneWidget);
    expect(find.text('Refresh sources'), findsNothing);

    await tester.tap(find.text('Sync account'));
    await tester.pumpAndSettle();

    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(find.text('Account synced'), findsOneWidget);
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

    await tester.tap(find.byIcon(FleurIcons.moreHorizontal));
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

    await tester.tap(find.byIcon(FleurIcons.moreHorizontal));
    await tester.pumpAndSettle();

    expect(find.text('Refresh sources'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);
  });
}
