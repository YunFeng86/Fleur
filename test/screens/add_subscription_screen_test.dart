import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/rss/feed_discovery_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';

import '../test_utils/isar_test_utils.dart';

const _asyncUiSettleAttempts = 300;

class _FakeFeedDiscoveryService extends FeedDiscoveryService {
  _FakeFeedDiscoveryService(this.candidates) : super(Dio());

  final List<DiscoveredFeed> candidates;

  @override
  Future<List<DiscoveredFeed>> discover(
    String input, {
    String? userAgent,
  }) async {
    return candidates;
  }
}

class _FakeSyncService implements SyncServiceBase {
  final List<int> refreshFeedCalls = <int>[];

  @override
  Future<int> offlineCacheFeed(int feedId) async => 0;

  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  }) async {
    refreshFeedCalls.add(feedId);
    return FeedRefreshResult(feedId: feedId, incomingCount: 0, newCount: 0);
  }

  @override
  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  }) async {
    return const BatchRefreshResult([]);
  }

  @override
  Future<BatchRefreshResult> syncAccountSafe({
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    Iterable<int>? feedIds,
  }) async {
    final ids = feedIds?.toList(growable: false) ?? const <int>[];
    onProgress?.call(ids.length, ids.length);
    return const BatchRefreshResult([]);
  }
}

class _FailingSyncService extends _FakeSyncService {
  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  }) async {
    refreshFeedCalls.add(feedId);
    return FeedRefreshResult(
      feedId: feedId,
      incomingCount: 0,
      newCount: 0,
      error: StateError('refresh failed'),
    );
  }
}

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return 'token';
  }

  @override
  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return null;
  }
}

class _FakeAppSettingsStore extends AppSettingsStore {
  _FakeAppSettingsStore(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {}
}

Dio _buildDio(
  Map<String, void Function(RequestOptions, RequestInterceptorHandler)> routes,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = '${options.method} ${options.uri.path}';
        final route = routes[key];
        if (route != null) {
          route(options, handler);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'unexpected request: $key',
          ),
        );
      },
    ),
  );
  return dio;
}

Account _localAccount() {
  final now = DateTime.fromMillisecondsSinceEpoch(0);
  return Account(
    id: 'local-test',
    type: AccountType.local,
    name: 'Local',
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );
}

Account _minifluxAccount() {
  final now = DateTime.fromMillisecondsSinceEpoch(0);
  return Account(
    id: 'miniflux-test',
    type: AccountType.miniflux,
    name: 'Miniflux',
    baseUrl: 'https://miniflux.example.com',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Isar isar,
  required FeedDiscoveryService discovery,
  Account? account,
  SyncServiceBase? sync,
  Dio? dio,
  bool withRouter = false,
  int? initialCategoryId,
}) async {
  final overrides = <Override>[
    isarProvider.overrideWithValue(isar),
    activeAccountProvider.overrideWithValue(account ?? _localAccount()),
    feedDiscoveryServiceProvider.overrideWithValue(discovery),
    syncServiceProvider.overrideWithValue(sync ?? _FakeSyncService()),
    appSettingsStoreProvider.overrideWithValue(
      _FakeAppSettingsStore(AppSettings.defaults()),
    ),
    if (dio != null) dioProvider.overrideWithValue(dio),
    credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
  ];

  if (!withRouter) {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddSubscriptionScreen(initialCategoryId: initialCategoryId),
        ),
      ),
    );
    return;
  }

  final router = GoRouter(
    initialLocation: initialCategoryId == null
        ? '/add-subscription'
        : '/add-subscription?categoryId=$initialCategoryId',
    routes: [
      GoRoute(
        path: '/add-subscription',
        builder: (context, state) => AddSubscriptionScreen(
          initialCategoryId: int.tryParse(
            state.uri.queryParameters['categoryId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/feed/:id',
        builder: (context, state) => Text('feed:${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

Future<void> _enterAndDiscover(WidgetTester tester, String input) async {
  await tester.enterText(
    find.byKey(const Key('add_subscription_url_field')),
    input,
  );
  await tester.tap(find.byKey(const Key('add_subscription_discover_button')));
  await _pumpFrames(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _tapAddResult(WidgetTester tester, String url) async {
  final finder = find.byKey(Key('add_subscription_result_add_$url'));
  await _pumpUntilFound(tester, finder);
  await _pumpUntilAbsent(
    tester,
    find.byKey(const Key('add_subscription_progress')),
  );
  await _tapVisible(tester, finder);
}

Finder _viewResultButton(String url) {
  return find.byKey(Key('add_subscription_result_view_$url'));
}

Future<void> _tapConfirmAdd(WidgetTester tester) async {
  final finder = find.byKey(const Key('add_subscription_confirm_add_button'));
  await _pumpUntilButtonEnabled(tester, finder);
  await _tapVisible(tester, finder);
  await tester.pump();
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = _asyncUiSettleAttempts,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  int attempts = _asyncUiSettleAttempts,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  expect(finder, findsNothing);
}

Future<void> _pumpUntilButtonEnabled(
  WidgetTester tester,
  Finder finder, {
  int attempts = _asyncUiSettleAttempts,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) continue;
    final button = tester.widget<FilledButton>(finder);
    if (button.onPressed != null) return;
  }
  expect(finder, findsOneWidget);
  expect(tester.widget<FilledButton>(finder).onPressed, isNotNull);
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_add_sub_page_');
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'add_subscription_screen_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    isar = null;
    tempDir = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('renders the add subscription task form', (tester) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const []),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('add_subscription_url_field')), findsOneWidget);
    expect(
      find.byKey(const Key('add_subscription_discover_button')),
      findsOneWidget,
    );
    expect(find.text('Find feeds'), findsOneWidget);
  });

  testWidgets('shows discovered subscription results with row previews', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(
          url: 'https://example.com/feed.xml',
          title: 'Feed A',
          siteTitle: 'Example Site',
          source: DiscoveredFeedSource.alternateLink,
          previewItems: [
            DiscoveredFeedPreviewItem(title: 'Article 1'),
            DiscoveredFeedPreviewItem(title: 'Article 2'),
            DiscoveredFeedPreviewItem(title: 'Article 3'),
            DiscoveredFeedPreviewItem(title: 'Article 4'),
          ],
        ),
        DiscoveredFeed(
          url: 'https://example.com/atom.xml',
          title: 'Feed B',
          siteTitle: 'Example Site',
          source: DiscoveredFeedSource.commonPath,
        ),
      ]),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_results')),
    );
    await _pumpUntilAbsent(
      tester,
      find.byKey(const Key('add_subscription_progress')),
    );

    expect(find.byKey(const Key('add_subscription_results')), findsOneWidget);
    expect(find.text('Found 2 subscription sources'), findsOneWidget);
    expect(
      find.byKey(
        const Key('add_subscription_result_https://example.com/feed.xml'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('add_subscription_result_https://example.com/atom.xml'),
      ),
      findsOneWidget,
    );
    expect(find.text('Feed A'), findsOneWidget);
    expect(find.text('Feed B'), findsOneWidget);
    expect(find.text('https://example.com/feed.xml'), findsOneWidget);
    expect(find.text('https://example.com/atom.xml'), findsOneWidget);
    expect(find.text('Discovered on page'), findsOneWidget);
    expect(find.text('Common feed path'), findsOneWidget);
    expect(find.text('Article 1'), findsOneWidget);
    expect(find.text('Article 2'), findsOneWidget);
    expect(find.text('Article 3'), findsOneWidget);
    expect(find.text('Article 4'), findsNothing);
    expect(find.text('No recent preview items available'), findsOneWidget);
    expect(find.text('Uncategorized'), findsNothing);
  });

  testWidgets('only the add button opens category confirmation', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(
        const Key('add_subscription_result_https://example.com/feed.xml'),
      ),
    );
    await _pumpUntilAbsent(
      tester,
      find.byKey(const Key('add_subscription_progress')),
    );
    final rowFinder = find.byKey(
      const Key('add_subscription_result_https://example.com/feed.xml'),
    );
    await tester.tapAt(tester.getTopLeft(rowFinder) + const Offset(80, 32));
    await tester.pump();
    expect(
      find.byKey(const Key('add_subscription_confirm_dialog')),
      findsNothing,
    );

    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_confirm_dialog')),
    );

    final dialogSize = tester.getSize(
      find.byKey(const Key('add_subscription_confirm_panel')),
    );
    expect(dialogSize.height, lessThan(420));
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('creates and selects a local category in confirmation dialog', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_show_new_category_button')),
    );
    await tester.tap(
      find.byKey(const Key('add_subscription_show_new_category_button')),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_new_category_field')),
    );
    await tester.enterText(
      find.byKey(const Key('add_subscription_new_category_field')),
      'Blogs',
    );
    final createButton = find.byKey(
      const Key('add_subscription_create_category_button'),
    );
    await _pumpUntilButtonEnabled(tester, createButton);
    await tester.tap(createButton);
    await _pumpUntilAbsent(
      tester,
      find.byKey(const Key('add_subscription_new_category_field')),
    );

    expect(find.text('Blogs'), findsOneWidget);
    expect(
      find.byKey(const Key('add_subscription_new_category_field')),
      findsNothing,
    );
  });

  testWidgets('category dropdown can select an existing local category', (
    tester,
  ) async {
    late final int categoryId;
    await tester.runAsync(() async {
      categoryId = await CategoryRepository(isar!).upsertByName('Blogs');
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.tap(
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blogs').last);
    await tester.pumpAndSettle();
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );

    late final Feed? feed;
    await tester.runAsync(() async {
      feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(feed, isNotNull);
    expect(feed!.categoryId, categoryId);
  });

  testWidgets('category picker filters long local category lists', (
    tester,
  ) async {
    late final int targetCategoryId;
    await tester.runAsync(() async {
      for (var index = 1; index <= 10; index++) {
        final id = await CategoryRepository(
          isar!,
        ).upsertByName('Category $index');
        if (index == 10) targetCategoryId = id;
      }
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.tap(
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.pumpAndSettle();

    final searchField = find.widgetWithIcon(TextField, FleurIcons.search);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Category 10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category 10').last);
    await tester.pumpAndSettle();
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );

    late final Feed? feed;
    await tester.runAsync(() async {
      feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(feed, isNotNull);
    expect(feed!.categoryId, targetCategoryId);
  });

  testWidgets('query category id preselects a local category', (tester) async {
    late final int categoryId;
    await tester.runAsync(() async {
      categoryId = await CategoryRepository(isar!).upsertByName('Blogs');
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
      initialCategoryId: categoryId,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(tester, find.text('Blogs'));
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );

    late final Feed? feed;
    await tester.runAsync(() async {
      feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(feed, isNotNull);
    expect(feed!.categoryId, categoryId);
  });

  testWidgets('Miniflux category picker does not offer uncategorized', (
    tester,
  ) async {
    final dio = _buildDio({
      'GET /v1/categories': (options, handler) {
        handler.resolve(
          Response<List<Map<String, Object?>>>(
            requestOptions: options,
            statusCode: 200,
            data: const [
              {'id': 42, 'title': 'Remote News'},
            ],
          ),
        );
      },
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      account: _minifluxAccount(),
      dio: dio,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.tap(
      find.byKey(const Key('add_subscription_category_dropdown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remote News'), findsOneWidget);
    expect(find.text('Uncategorized'), findsNothing);
  });

  testWidgets('Miniflux preselects a remote category from local remoteId', (
    tester,
  ) async {
    late final int categoryId;
    await tester.runAsync(() async {
      categoryId = await CategoryRepository(
        isar!,
      ).upsertRemote(remoteId: '42', name: 'News');
    });
    final dio = _buildDio({
      'GET /v1/categories': (options, handler) {
        handler.resolve(
          Response<List<Map<String, Object?>>>(
            requestOptions: options,
            statusCode: 200,
            data: const [
              {'id': 42, 'title': 'Remote News'},
            ],
          ),
        );
      },
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      account: _minifluxAccount(),
      dio: dio,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
      initialCategoryId: categoryId,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(tester, find.text('Remote News'));

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('add_subscription_confirm_add_button')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('shows no feeds found as an inline error', (tester) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const []),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_error')),
    );

    expect(find.byKey(const Key('add_subscription_error')), findsOneWidget);
    expect(find.textContaining('No feeds found'), findsWidgets);
    expect(
      find.textContaining('Paste the RSS/Atom URL directly'),
      findsWidgets,
    );
  });

  testWidgets('success stays on add page and continue resets the form', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(tester, find.text('Uncategorized'));
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );

    expect(find.text('Subscription added'), findsWidgets);
    expect(find.text('feed:'), findsNothing);

    await _tapVisible(
      tester,
      find.byKey(const Key('add_subscription_continue_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_subscription_results')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('add_subscription_url_field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('initial refresh failure keeps success and shows warning', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      sync: _FailingSyncService(),
      withRouter: true,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(tester, find.text('Uncategorized'));
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_warning')),
    );

    expect(find.byKey(const Key('add_subscription_warning')), findsOneWidget);
    expect(find.byKey(const Key('add_subscription_error')), findsNothing);
  });

  testWidgets('view subscription opens the feed route after success', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed'),
      ]),
      withRouter: true,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml');
    await _tapAddResult(tester, 'https://example.com/feed.xml');
    await _pumpUntilFound(tester, find.text('Uncategorized'));
    await _tapConfirmAdd(tester);
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml'),
    );
    late final Feed? feed;
    await tester.runAsync(() async {
      feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(feed, isNotNull);

    await tester.tap(_viewResultButton('https://example.com/feed.xml'));
    await tester.pumpAndSettle();

    expect(find.text('feed:${feed!.id}'), findsOneWidget);
  });

  testWidgets('existing subscriptions stay put until move is requested', (
    tester,
  ) async {
    late final int originalCategoryId;
    late final int targetCategoryId;
    await tester.runAsync(() async {
      final categories = CategoryRepository(isar!);
      final feeds = FeedRepository(isar!);
      originalCategoryId = await categories.upsertByName('Original');
      targetCategoryId = await categories.upsertByName('Target');
      final existingFeedId = await feeds.upsertUrl(
        'https://example.com/feed.xml',
      );
      await feeds.setCategory(
        feedId: existingFeedId,
        categoryId: originalCategoryId,
      );
    });

    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml/', title: 'Feed'),
      ]),
      withRouter: true,
      initialCategoryId: targetCategoryId,
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com/feed.xml/');
    await _pumpUntilFound(
      tester,
      find.byKey(
        const Key('add_subscription_result_move_https://example.com/feed.xml/'),
      ),
    );

    expect(find.text('Already subscribed'), findsWidgets);
    expect(
      find.byKey(
        const Key('add_subscription_result_move_https://example.com/feed.xml/'),
      ),
      findsOneWidget,
    );
    late final Feed? feed;
    await tester.runAsync(() async {
      feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(feed, isNotNull);
    expect(feed!.categoryId, originalCategoryId);

    await _tapVisible(
      tester,
      find.byKey(
        const Key('add_subscription_result_move_https://example.com/feed.xml/'),
      ),
    );
    await _pumpUntilFound(
      tester,
      _viewResultButton('https://example.com/feed.xml/'),
    );
    late final Feed? movedFeed;
    await tester.runAsync(() async {
      movedFeed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
    });
    expect(movedFeed, isNotNull);
    expect(movedFeed!.categoryId, targetCategoryId);
  });

  test(
    'controller uses scoped Isar override when discovering in account scope',
    () async {
      final root = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWithValue(_localAccount()),
          feedDiscoveryServiceProvider.overrideWithValue(
            _FakeFeedDiscoveryService(const [
              DiscoveredFeed(
                url: 'https://example.com/feed.xml',
                title: 'Scoped Feed',
              ),
            ]),
          ),
          appSettingsStoreProvider.overrideWithValue(
            _FakeAppSettingsStore(AppSettings.defaults()),
          ),
        ],
      );
      addTearDown(root.dispose);

      final scoped = ProviderContainer(
        parent: root,
        overrides: [isarProvider.overrideWithValue(isar!)],
      );
      addTearDown(scoped.dispose);
      final subscription = scoped.listen(
        addSubscriptionControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = scoped.read(
        addSubscriptionControllerProvider.notifier,
      );
      await controller.discover('https://example.com/feed.xml');

      final state = scoped.read(addSubscriptionControllerProvider);
      expect(state.failure, isNull);
      expect(state.candidates, hasLength(1));
      expect(state.candidates.single.feed.title, 'Scoped Feed');
    },
  );

  test(
    'controller submits a local subscription and returns the feed id',
    () async {
      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar!),
          activeAccountProvider.overrideWithValue(_localAccount()),
          feedDiscoveryServiceProvider.overrideWithValue(
            _FakeFeedDiscoveryService(const [
              DiscoveredFeed(
                url: 'https://example.com/feed.xml',
                title: 'Feed',
              ),
            ]),
          ),
          syncServiceProvider.overrideWithValue(_FakeSyncService()),
          appSettingsStoreProvider.overrideWithValue(
            _FakeAppSettingsStore(AppSettings.defaults()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        addSubscriptionControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(
        addSubscriptionControllerProvider.notifier,
      );
      await controller.discover('https://example.com/feed.xml');
      expect(
        container.read(addSubscriptionControllerProvider).phase,
        AddSubscriptionPhase.selectingCategory,
      );

      final id = await controller.submit();

      expect(id, isNotNull);
      final feed = await FeedRepository(
        isar!,
      ).getByUrl('https://example.com/feed.xml');
      expect(feed, isNotNull);
      expect(feed!.id, id);
    },
  );

  test(
    'controller submits a Miniflux subscription after local mirror',
    () async {
      const feedUrl = 'https://example.com/feed.xml';
      final sync = _FakeSyncService();
      final dio = _buildDio({
        'GET /v1/categories': (options, handler) {
          handler.resolve(
            Response<List<Map<String, Object?>>>(
              requestOptions: options,
              statusCode: 200,
              data: const [
                {'id': 42, 'title': 'Remote News'},
              ],
            ),
          );
        },
        'GET /v1/feeds': (options, handler) {
          handler.resolve(
            Response<List<Map<String, Object?>>>(
              requestOptions: options,
              statusCode: 200,
              data: const [
                {
                  'id': 99,
                  'feed_url': feedUrl,
                  'title': 'Remote Feed',
                  'site_url': 'https://example.com',
                  'category_id': 42,
                },
              ],
            ),
          );
        },
        'POST /v1/feeds': (options, handler) {
          expect(options.data, {'feed_url': feedUrl, 'category_id': 42});
          handler.resolve(
            Response<Map<String, Object?>>(
              requestOptions: options,
              statusCode: 201,
              data: const {'id': 99, 'feed_url': feedUrl},
            ),
          );
        },
      });
      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar!),
          activeAccountProvider.overrideWithValue(_minifluxAccount()),
          dioProvider.overrideWithValue(dio),
          credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
          feedDiscoveryServiceProvider.overrideWithValue(
            _FakeFeedDiscoveryService(const [
              DiscoveredFeed(url: feedUrl, title: 'Feed'),
            ]),
          ),
          syncServiceProvider.overrideWithValue(sync),
          appSettingsStoreProvider.overrideWithValue(
            _FakeAppSettingsStore(AppSettings.defaults()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        addSubscriptionControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(
        addSubscriptionControllerProvider.notifier,
      );
      await controller.discover(feedUrl);
      await controller.selectCandidate(
        container.read(addSubscriptionControllerProvider).candidates.single,
      );
      controller.selectCategory(
        const AddSubscriptionCategoryOption(id: 42, title: 'Remote News'),
      );

      final id = await controller.submit();

      expect(id, isNotNull);
      final feed = await FeedRepository(isar!).getByUrl(feedUrl);
      expect(feed, isNotNull);
      expect(feed!.id, id);
      expect(feed.remoteId, '99');
      expect(feed.title, 'Remote Feed');
      final state = container.read(addSubscriptionControllerProvider);
      expect(state.phase, AddSubscriptionPhase.success);
      expect(state.refreshWarning, isNull);
      expect(sync.refreshFeedCalls, [feed.id]);
    },
  );
}
