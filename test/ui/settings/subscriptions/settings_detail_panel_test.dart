import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/subscription_settings_provider.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/settings/subscriptions/subscription_layout_manager.dart';
import 'package:fleur/ui/settings/subscriptions/settings_detail_panel.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  _FakeFeedRepository(this.controller, this.currentFeed);

  final StreamController<Feed?> controller;
  Feed currentFeed;

  @override
  Future<void> updateSettings({
    required int id,
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
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) async {
    if (updateFilterEnabled) currentFeed.filterEnabled = filterEnabled;
    if (updateFilterKeywords) currentFeed.filterKeywords = filterKeywords;
    if (updateSyncEnabled) currentFeed.syncEnabled = syncEnabled;
    if (updateSyncImages) currentFeed.syncImages = syncImages;
    if (updateSyncWebPages) currentFeed.syncWebPages = syncWebPages;
    if (updateShowAiSummary) currentFeed.showAiSummary = showAiSummary;
    if (updateAutoTranslate) currentFeed.autoTranslate = autoTranslate;
    controller.add(currentFeed);
  }
}

void main() {
  Category buildCategory() {
    return Category()
      ..id = 1
      ..name = 'Tech'
      ..autoTranslate = true;
  }

  Feed buildFeed() {
    return Feed()
      ..id = 42
      ..url = 'https://example.com/feed.xml'
      ..title = 'Example Feed'
      ..categoryId = 1
      ..autoTranslate = null;
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    required FakeAppSettingsStore appStore,
    required Feed feed,
    required Category category,
    required FeedRepository feedRepository,
    required Stream<Feed?> feedStream,
    Account? account,
  }) async {
    await pumpLocalizedTestApp(
      tester,
      home: const Scaffold(body: SettingsDetailPanel()),
      overrides: [
        activeAccountProvider.overrideWithValue(account ?? buildTestAccount()),
        appSettingsStoreProvider.overrideWithValue(appStore),
        feedsProvider.overrideWith((ref) => Stream.value([feed])),
        categoriesProvider.overrideWith((ref) => Stream.value([category])),
        categoryProvider(
          category.id,
        ).overrideWith((ref) => Stream.value(category)),
        feedProvider(feed.id).overrideWith((ref) async* {
          yield feed;
          yield* feedStream;
        }),
        feedRepositoryProvider.overrideWithValue(feedRepository),
      ],
      size: const Size(900, 1200),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpLayoutManager(
    WidgetTester tester, {
    required FakeAppSettingsStore appStore,
    required Feed feed,
    required Category category,
    required FeedRepository feedRepository,
    required Stream<Feed?> feedStream,
    Account? account,
  }) async {
    await pumpLocalizedTestApp(
      tester,
      home: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SubscriptionLayoutManager()),
      ),
      overrides: [
        activeAccountProvider.overrideWithValue(account ?? buildTestAccount()),
        appSettingsStoreProvider.overrideWithValue(appStore),
        feedsProvider.overrideWith((ref) => Stream.value([feed])),
        categoriesProvider.overrideWith((ref) => Stream.value([category])),
        categoryProvider(
          category.id,
        ).overrideWith((ref) => Stream.value(category)),
        feedProvider(feed.id).overrideWith((ref) async* {
          yield feed;
          yield* feedStream;
        }),
        feedRepositoryProvider.overrideWithValue(feedRepository),
      ],
      size: const Size(1280, 900),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders global defaults by default and updates global defaults',
    (tester) async {
      final category = buildCategory();
      final feed = buildFeed();
      final feedController = StreamController<Feed?>.broadcast();
      addTearDown(feedController.close);
      final fakeRepo = _FakeFeedRepository(feedController, feed);
      final appStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(autoTranslate: false),
      );

      await pumpPanel(
        tester,
        appStore: appStore,
        feed: feed,
        category: category,
        feedRepository: fakeRepo,
        feedStream: feedController.stream,
      );

      expect(find.text('Global defaults'), findsOneWidget);
      expect(find.text('Auto translate'), findsOneWidget);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Auto translate'));
      await tester.pumpAndSettle();

      expect(appStore.settings.autoTranslate, isTrue);
    },
  );

  testWidgets('renders category details when a category is selected', (
    tester,
  ) async {
    final category = buildCategory();
    final feed = buildFeed();
    final feedController = StreamController<Feed?>.broadcast();
    addTearDown(feedController.close);
    final fakeRepo = _FakeFeedRepository(feedController, feed);
    final appStore = FakeAppSettingsStore(AppSettings.defaults());

    await pumpPanel(
      tester,
      appStore: appStore,
      feed: feed,
      category: category,
      feedRepository: fakeRepo,
      feedStream: feedController.stream,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsDetailPanel)),
    );
    container.read(subscriptionSelectionProvider.notifier).selectCategory(1);
    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
    'supports feed override and reset back to inherited auto-translate',
    (tester) async {
      final category = buildCategory();
      final feed = buildFeed();
      final feedController = StreamController<Feed?>.broadcast();
      addTearDown(feedController.close);
      final fakeRepo = _FakeFeedRepository(feedController, feed);
      final appStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(autoTranslate: false),
      );

      await pumpPanel(
        tester,
        appStore: appStore,
        feed: feed,
        category: category,
        feedRepository: fakeRepo,
        feedStream: feedController.stream,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDetailPanel)),
      );
      container
          .read(subscriptionSelectionProvider.notifier)
          .selectFeed(
            feed.id,
            categoryScope: SubscriptionCategoryId(category.id),
          );
      await tester.pumpAndSettle();

      expect(find.text('Example Feed'), findsOneWidget);
      final tile = find.ancestor(
        of: find.text('Auto translate'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.refresh)),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.byIcon(Icons.arrow_drop_down)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Off').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakeRepo.currentFeed.autoTranslate, isFalse);
      expect(find.text('Off'), findsWidgets);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.refresh)),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: tile, matching: find.byIcon(Icons.refresh)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(fakeRepo.currentFeed.autoTranslate, isNull);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.refresh)),
        findsNothing,
      );
    },
  );

  testWidgets('renders feed detail header and destructive action', (
    tester,
  ) async {
    final category = buildCategory();
    final feed = buildFeed();
    final feedController = StreamController<Feed?>.broadcast();
    addTearDown(feedController.close);
    final fakeRepo = _FakeFeedRepository(feedController, feed);
    final appStore = FakeAppSettingsStore(AppSettings.defaults());

    await pumpPanel(
      tester,
      appStore: appStore,
      feed: feed,
      category: category,
      feedRepository: fakeRepo,
      feedStream: feedController.stream,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsDetailPanel)),
    );
    container
        .read(subscriptionSelectionProvider.notifier)
        .selectFeed(
          feed.id,
          categoryScope: SubscriptionCategoryId(category.id),
        );
    await tester.pumpAndSettle();

    expect(find.text('Example Feed'), findsOneWidget);
    expect(find.text('https://example.com/feed.xml'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('Fever feed details hide remote structure actions', (
    tester,
  ) async {
    final category = buildCategory();
    final feed = buildFeed();
    final feedController = StreamController<Feed?>.broadcast();
    addTearDown(feedController.close);
    final fakeRepo = _FakeFeedRepository(feedController, feed);
    final appStore = FakeAppSettingsStore(AppSettings.defaults());

    await pumpPanel(
      tester,
      appStore: appStore,
      feed: feed,
      category: category,
      feedRepository: fakeRepo,
      feedStream: feedController.stream,
      account: buildTestAccount(type: AccountType.fever),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsDetailPanel)),
    );
    container
        .read(subscriptionSelectionProvider.notifier)
        .selectFeed(
          feed.id,
          categoryScope: SubscriptionCategoryId(category.id),
        );
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Move to category'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Download Images during Sync'), findsOneWidget);
    expect(find.text('Download Web Pages during Sync'), findsOneWidget);
  });

  testWidgets('Fever global sync content fetch settings remain editable', (
    tester,
  ) async {
    final category = buildCategory();
    final feed = buildFeed();
    final feedController = StreamController<Feed?>.broadcast();
    addTearDown(feedController.close);
    final fakeRepo = _FakeFeedRepository(feedController, feed);
    final appStore = FakeAppSettingsStore(
      AppSettings.defaults().copyWith(syncImages: true, syncWebPages: false),
    );

    await pumpPanel(
      tester,
      appStore: appStore,
      feed: feed,
      category: category,
      feedRepository: fakeRepo,
      feedStream: feedController.stream,
      account: buildTestAccount(type: AccountType.fever),
    );

    expect(find.text('Download Images during Sync'), findsOneWidget);
    expect(find.text('Download Web Pages during Sync'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Download Images during Sync'),
    );
    await tester.pumpAndSettle();
    expect(appStore.settings.syncImages, isFalse);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Download Web Pages during Sync'),
    );
    await tester.pumpAndSettle();
    expect(appStore.settings.syncWebPages, isTrue);
  });

  testWidgets(
    'wide layout starts in global defaults and keeps the feed list visible',
    (tester) async {
      final category = buildCategory();
      final feed = buildFeed();
      final feedController = StreamController<Feed?>.broadcast();
      addTearDown(feedController.close);
      final fakeRepo = _FakeFeedRepository(feedController, feed);
      final appStore = FakeAppSettingsStore(AppSettings.defaults());

      await pumpLayoutManager(
        tester,
        appStore: appStore,
        feed: feed,
        category: category,
        feedRepository: fakeRepo,
        feedStream: feedController.stream,
      );

      expect(find.text('Global defaults'), findsWidgets);
      expect(find.text('Example Feed'), findsOneWidget);
      expect(find.text('Auto translate'), findsOneWidget);
    },
  );

  test(
    'selectCategory toggles back to root when tapping the current category',
    () {
      final notifier = SubscriptionSelectionNotifier();

      notifier.selectCategory(1);
      expect(notifier.state.activeCategoryId, 1);
      expect(notifier.state.isGlobalDefaults, isFalse);

      notifier.selectCategory(1);
      expect(notifier.state.categoryScope, isA<SubscriptionCategoryAll>());
      expect(notifier.state.isGlobalDefaults, isTrue);
      expect(notifier.state.showDetailPane, isFalse);
    },
  );

  test('handleBack closes the detail pane before leaving narrow layouts', () {
    final notifier = SubscriptionSelectionNotifier();

    notifier.showGlobalDefaults(showDetailPane: true);
    expect(notifier.state.showDetailPane, isTrue);
    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.showDetailPane, isFalse);
    expect(notifier.state.isGlobalDefaults, isTrue);

    notifier.selectCategory(1, showDetailPane: true);
    expect(notifier.state.showDetailPane, isTrue);
    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.showDetailPane, isFalse);
    expect(notifier.state.activeCategoryId, 1);
  });
}
