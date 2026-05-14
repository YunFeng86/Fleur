import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/add_subscription_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/screens/add_subscription_screen.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/rss/feed_discovery_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/theme/app_theme.dart';

import '../test_utils/isar_test_utils.dart';

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
  @override
  Future<int> offlineCacheFeed(int feedId) async => 0;

  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  }) async {
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
          home: const AddSubscriptionScreen(),
        ),
      ),
    );
    return;
  }

  final router = GoRouter(
    initialLocation: '/add-subscription',
    routes: [
      GoRoute(
        path: '/add-subscription',
        builder: (context, state) => const AddSubscriptionScreen(),
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
  int attempts = 20,
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
  int attempts = 20,
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
  });

  testWidgets('shows feed candidates in-page and then local categories', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isar: isar!,
      discovery: _FakeFeedDiscoveryService(const [
        DiscoveredFeed(url: 'https://example.com/feed.xml', title: 'Feed A'),
        DiscoveredFeed(url: 'https://example.com/atom.xml', title: 'Feed B'),
      ]),
    );
    await _pumpFrames(tester);

    await _enterAndDiscover(tester, 'https://example.com');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('add_subscription_feed_candidates')),
    );

    expect(
      find.byKey(const Key('add_subscription_feed_candidates')),
      findsOneWidget,
    );
    expect(find.text('Feed A'), findsOneWidget);
    expect(find.text('Feed B'), findsOneWidget);

    await tester.tap(find.text('Feed B'));
    await _pumpUntilFound(tester, find.text('Uncategorized'));

    expect(
      find.byKey(const Key('add_subscription_selected_feed')),
      findsOneWidget,
    );
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('creates and selects a local category in-page', (tester) async {
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
    await tester.tap(
      find.byKey(const Key('add_subscription_create_category_button')),
    );
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
    await _pumpUntilFound(tester, find.text('Remote News'));

    expect(find.text('Remote News'), findsOneWidget);
    expect(find.text('Uncategorized'), findsNothing);
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
    expect(find.text('No feeds found'), findsWidgets);
  });

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
}
