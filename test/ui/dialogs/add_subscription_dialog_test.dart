import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/app/app.dart';
import 'package:fleur/app/router.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/l10n/app_localizations_en.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/rss/feed_discovery_service.dart';
import 'package:fleur/ui/dialogs/add_subscription_dialog.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import '../../test_utils/isar_test_utils.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;
}

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

void main() {
  Isar? isar;
  Directory? tempDir;
  late PathProviderPlatform originalPlatform;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ensureIsarCoreInitialized();
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_add_sub_dialog_');
    final docs = await Directory(
      '${tempDir!.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir!.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir!.path}/cache',
    ).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
      cachePath: cache.path,
    );
    PathManager.resetForTests();
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'add_subscription_dialog_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    PathProviderPlatform.instance = originalPlatform;
    PathManager.resetForTests();
    final dir = tempDir;
    tempDir = null;
    isar = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('AddSubscriptionDialog barrier dismiss should not throw', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) {
            return Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    return ElevatedButton(
                      key: const Key('open_add_subscription_dialog'),
                      onPressed: () async {
                        await showAddSubscriptionDialog(context, ref);
                      },
                      child: const Text('open'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(router),
          isarProvider.overrideWithValue(isar!),
        ],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('open_add_subscription_dialog')));
    await tester.pump(); // start route push animation
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(AlertDialog), findsOneWidget);

    // Dismiss quickly by tapping outside the dialog (i.e. the modal barrier),
    // to simulate the crashy scenario.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(); // start pop animation
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // finish pop animation
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
  });

  testWidgets('feed candidate picker uses AppScrollbar', (tester) async {
    final service = _FakeFeedDiscoveryService(const [
      DiscoveredFeed(url: 'https://example.com/feed-a.xml', title: 'Feed A'),
      DiscoveredFeed(url: 'https://example.com/feed-b.xml', title: 'Feed B'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            Account(
              id: 'local-test',
              type: AccountType.local,
              name: 'Local',
              isPrimary: true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ),
          feedDiscoveryServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return FilledButton(
                  onPressed: () async {
                    await showAddSubscriptionDialog(context, ref);
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Add'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      if (find.text('Select a feed').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Select a feed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(AppScrollbar),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
  });

  test(
    'Miniflux add-subscription failure feedback maps connectivity errors clearly',
    () {
      final message = addSubscriptionRemoteStructureFailureMessageForTest(
        AppLocalizationsEn(),
        DioException(
          requestOptions: RequestOptions(path: '/v1/categories'),
          type: DioExceptionType.connectionError,
          error: const SocketException('offline'),
        ),
      );

      expect(
        message,
        'This action requires connectivity to the remote service.',
      );
    },
  );

  test('Miniflux add-subscription HTTP errors do not use connectivity copy', () {
    final request = RequestOptions(path: '/v1/categories');
    final message = addSubscriptionRemoteStructureFailureMessageForTest(
      AppLocalizationsEn(),
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: request,
          statusCode: 401,
          data: const {'error_message': 'Unauthorized'},
        ),
      ),
    );

    expect(
      message,
      'The remote service rejected the current account credentials. Check the account settings and try again.',
    );
  });

  test('Miniflux add-subscription target drift still uses sync copy', () {
    final message = addSubscriptionRemoteStructureFailureMessageForTest(
      AppLocalizationsEn(),
      StateError('Remote category not found for title: News'),
    );

    expect(
      message,
      'The remote service could not match the current feed or category. Sync and try again.',
    );
  });
}
