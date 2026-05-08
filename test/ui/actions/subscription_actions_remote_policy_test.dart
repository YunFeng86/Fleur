import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/l10n/app_localizations_en.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/ui/actions/subscription_actions.dart';

import '../../test_utils/isar_test_utils.dart';

class _FakeCredentialStore extends CredentialStore {
  _FakeCredentialStore({this.apiToken});

  final String? apiToken;

  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return apiToken;
  }

  @override
  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return null;
  }
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

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_subscription_actions_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'subscription_actions_remote_policy_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    tempDir = null;
    isar = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'deleteFeed keeps local data when Miniflux remote delete fails',
    () async {
      final now = DateTime.utc(2026, 3, 1, 10, 0);
      await isar!.writeTxn(() async {
        final feed = Feed()
          ..id = 1
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);
      });

      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar!),
          activeAccountProvider.overrideWithValue(
            Account(
              id: 'miniflux-feed-delete',
              type: AccountType.miniflux,
              name: 'Miniflux',
              baseUrl: 'https://miniflux.example.com',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          dioProvider.overrideWithValue(
            _buildDio({
              'GET /v1/feeds': (options, handler) {
                handler.resolve(
                  Response<List<Map<String, Object?>>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const [
                      {
                        'id': 91,
                        'feed_url': 'https://example.com/feed.xml',
                        'title': 'Feed',
                      },
                    ],
                  ),
                );
              },
              'DELETE /v1/feeds/91': (options, handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    error: const SocketException('offline'),
                  ),
                );
              },
            }),
          ),
          credentialStoreProvider.overrideWithValue(
            _FakeCredentialStore(apiToken: 'token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => SubscriptionActions.deleteFeedConfirmedCoreFromRead(
          container.read,
          1,
        ),
        throwsA(isA<DioException>()),
      );

      expect(await FeedRepository(isar!).getById(1), isNotNull);
    },
  );

  test(
    'deleteCategory keeps local data when Miniflux remote delete fails',
    () async {
      final now = DateTime.utc(2026, 3, 1, 11, 0);
      await isar!.writeTxn(() async {
        final category = Category()
          ..id = 7
          ..name = 'Remote Category'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.categorys.put(category);
      });

      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar!),
          activeAccountProvider.overrideWithValue(
            Account(
              id: 'miniflux-category-delete',
              type: AccountType.miniflux,
              name: 'Miniflux',
              baseUrl: 'https://miniflux.example.com',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          dioProvider.overrideWithValue(
            _buildDio({
              'GET /v1/categories': (options, handler) {
                handler.resolve(
                  Response<List<Map<String, Object?>>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const [
                      {'id': 22, 'title': 'Remote Category'},
                    ],
                  ),
                );
              },
              'DELETE /v1/categories/22': (options, handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    error: const SocketException('offline'),
                  ),
                );
              },
            }),
          ),
          credentialStoreProvider.overrideWithValue(
            _FakeCredentialStore(apiToken: 'token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        () => SubscriptionActions.deleteCategoryConfirmedCoreFromRead(
          container.read,
          7,
        ),
        throwsA(isA<DioException>()),
      );

      expect(await CategoryRepository(isar!).getById(7), isNotNull);
    },
  );

  test(
    'deleteCategory keeps truthful local state after remote success even when reconciliation fails',
    () async {
      final now = DateTime.utc(2026, 3, 1, 11, 30);
      await isar!.writeTxn(() async {
        final category = Category()
          ..id = 7
          ..name = 'Remote Category'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.categorys.put(category);

        final feed = Feed()
          ..id = 3
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..categoryId = 7
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);
      });

      var categoryFetches = 0;
      final container = ProviderContainer(
        overrides: [
          isarProvider.overrideWithValue(isar!),
          activeAccountProvider.overrideWithValue(
            Account(
              id: 'miniflux-category-delete-reconcile',
              type: AccountType.miniflux,
              name: 'Miniflux',
              baseUrl: 'https://miniflux.example.com',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          dioProvider.overrideWithValue(
            _buildDio({
              'GET /v1/categories': (options, handler) {
                categoryFetches += 1;
                if (categoryFetches == 1) {
                  handler.resolve(
                    Response<List<Map<String, Object?>>>(
                      requestOptions: options,
                      statusCode: 200,
                      data: const [
                        {'id': 22, 'title': 'Remote Category'},
                      ],
                    ),
                  );
                  return;
                }
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response<Map<String, Object?>>(
                      requestOptions: options,
                      statusCode: 500,
                      data: const {'error_message': 'server error'},
                    ),
                  ),
                );
              },
              'DELETE /v1/categories/22': (options, handler) {
                handler.resolve(
                  Response<void>(requestOptions: options, statusCode: 204),
                );
              },
            }),
          ),
          credentialStoreProvider.overrideWithValue(
            _FakeCredentialStore(apiToken: 'token'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await SubscriptionActions.deleteCategoryConfirmedCoreFromRead(
        container.read,
        7,
      );

      expect(await CategoryRepository(isar!).getById(7), isNull);
      expect((await FeedRepository(isar!).getById(3))?.categoryId, isNull);
    },
  );

  test('remote failure feedback maps connectivity errors clearly', () {
    final message = SubscriptionActions.remoteStructureFailureMessageForTest(
      AppLocalizationsEn(),
      DioException(
        requestOptions: RequestOptions(path: '/v1/feeds/91'),
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      ),
    );

    expect(message, 'This action requires connectivity to the remote service.');
  });

  test('remote failure feedback keeps HTTP errors out of connectivity copy', () {
    final request = RequestOptions(path: '/v1/feeds/91');
    final message = SubscriptionActions.remoteStructureFailureMessageForTest(
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

  test('remote failure feedback keeps target drift on sync copy', () {
    final message = SubscriptionActions.remoteStructureFailureMessageForTest(
      AppLocalizationsEn(),
      StateError('Remote feed not found for url: https://example.com/feed.xml'),
    );

    expect(
      message,
      'The remote service could not match the current feed or category. Sync and try again.',
    );
  });

  test(
    'remote failure feedback maps server errors to remote availability copy',
    () {
      final request = RequestOptions(path: '/v1/feeds/91');
      final message = SubscriptionActions.remoteStructureFailureMessageForTest(
        AppLocalizationsEn(),
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, Object?>>(
            requestOptions: request,
            statusCode: 503,
            data: const {'error_message': 'Service unavailable'},
          ),
        ),
      );

      expect(
        message,
        'The remote service could not complete this action right now. Try again later.',
      );
    },
  );

  test(
    'FeedRepository clears a custom title when given an empty string',
    () async {
      final now = DateTime.utc(2026, 3, 1, 12, 0);
      await isar!.writeTxn(() async {
        final feed = Feed()
          ..id = 9
          ..url = 'https://example.com/custom.xml'
          ..title = 'Feed'
          ..userTitle = 'Custom title'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);
      });

      await FeedRepository(isar!).setUserTitle(feedId: 9, userTitle: '');

      expect((await FeedRepository(isar!).getById(9))?.userTitle, isNull);
    },
  );

  test(
    'remote feed update reconciliation uses the accepted remote category and metadata',
    () async {
      final now = DateTime.utc(2026, 3, 1, 13, 0);
      await isar!.writeTxn(() async {
        final category = Category()
          ..id = 7
          ..name = 'Chosen Local Category'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.categorys.put(category);

        final feed = Feed()
          ..id = 1
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);
      });

      final container = ProviderContainer(
        overrides: [isarProvider.overrideWithValue(isar!)],
      );
      addTearDown(container.dispose);

      await SubscriptionActions.reconcileLocalFeedFromRemoteUpdateForTest(
        container.read,
        1,
        const {
          'id': 91,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Server Feed Title',
          'site_url': 'https://example.com',
          'description': 'Remote description',
          'category': {'id': 23, 'title': 'Server Accepted Category'},
        },
        fallbackCategoryId: 7,
      );

      final categories = await CategoryRepository(isar!).getAll();
      final reconciledCategory = categories.firstWhere(
        (category) => category.name == 'Server Accepted Category',
      );
      final updatedFeed = await FeedRepository(isar!).getById(1);
      final feeds = await FeedRepository(isar!).getAll();

      expect(feeds, hasLength(1));
      expect(updatedFeed?.remoteId, '91');
      expect(updatedFeed?.categoryId, reconciledCategory.id);
      expect(updatedFeed?.title, 'Server Feed Title');
      expect(updatedFeed?.siteUrl, 'https://example.com');
      expect(updatedFeed?.description, 'Remote description');
    },
  );

  test(
    'remote feed reconciliation binds equivalent url to the current local feed',
    () async {
      final now = DateTime.utc(2026, 3, 1, 13, 30);
      await isar!.writeTxn(() async {
        final category = Category()
          ..id = 7
          ..name = 'Chosen Local Category'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.categorys.put(category);

        final feed = Feed()
          ..id = 1
          ..url = 'https://example.com/feed.xml/'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);
      });

      final container = ProviderContainer(
        overrides: [isarProvider.overrideWithValue(isar!)],
      );
      addTearDown(container.dispose);

      await SubscriptionActions.reconcileLocalFeedFromRemoteUpdateForTest(
        container.read,
        1,
        const {
          'id': 91,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Server Feed Title',
          'site_url': 'https://example.com',
          'description': 'Remote description',
          'category': {'id': 23, 'title': 'Server Accepted Category'},
        },
        fallbackCategoryId: 7,
      );

      final categories = await CategoryRepository(isar!).getAll();
      final reconciledCategory = categories.firstWhere(
        (category) => category.name == 'Server Accepted Category',
      );
      final feeds = await FeedRepository(isar!).getAll();
      final updatedFeed = await FeedRepository(isar!).getById(1);

      expect(feeds, hasLength(1));
      expect(updatedFeed?.remoteId, '91');
      expect(updatedFeed?.url, 'https://example.com/feed.xml');
      expect(updatedFeed?.categoryId, reconciledCategory.id);
      expect(updatedFeed?.title, 'Server Feed Title');
      expect(updatedFeed?.siteUrl, 'https://example.com');
      expect(updatedFeed?.description, 'Remote description');
    },
  );

  testWidgets('editFeedTitle dialog exposes a delete action', (tester) async {
    final controller = TextEditingController(text: 'Custom title');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return SubscriptionActions.buildEditFeedTitleDialogForTest(
              context,
              l10n: l10n,
              controller: controller,
            );
          },
        ),
      ),
    );

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('editFeedTitle delete action closes with an empty result', (
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
                        return SubscriptionActions.buildEditFeedTitleDialogForTest(
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
