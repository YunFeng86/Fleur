@Tags(['global_logger'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/sync/google_reader/google_reader_provider_profile.dart';
import 'package:fleur/ui/dialogs/add_account_dialogs.dart';
import 'package:fleur/utils/path_manager.dart';

import '../../test_utils/critical_workflow_test_support.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
    required String temporaryPath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath,
       _temporaryPath = temporaryPath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;
  final String _temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}

class _ThrowingAccountStore extends AccountStore {
  @override
  Future<AccountsState> loadOrCreate() async {
    final now = DateTime.utc(2026, 1, 1);
    return AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: 'local',
      accounts: [
        Account(
          id: 'local',
          type: AccountType.local,
          name: 'Local',
          isPrimary: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }

  @override
  Future<void> save(AccountsState state) async {
    throw StateError('account save failed');
  }
}

Widget _buildLauncher() {
  return Scaffold(
    body: Center(
      child: Consumer(
        builder: (context, ref, _) {
          final readerAccount = ref
              .watch(accountsControllerProvider)
              .valueOrNull
              ?.findById('reader');
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                key: const Key('open_google_reader'),
                onPressed: () async {
                  await showAddGoogleReaderAccountDialog(context, ref);
                },
                child: const Text('open google reader'),
              ),
              FilledButton(
                key: const Key('open_google_reader_edit'),
                onPressed: readerAccount == null
                    ? null
                    : () async {
                        await showEditGoogleReaderAccountDialog(
                          context,
                          ref,
                          readerAccount,
                        );
                      },
                child: const Text('edit google reader'),
              ),
              FilledButton(
                key: const Key('open_fever'),
                onPressed: () async {
                  await showAddFeverAccountDialog(context, ref);
                },
                child: const Text('open fever'),
              ),
              FilledButton(
                key: const Key('open_miniflux'),
                onPressed: () async {
                  await showAddMinifluxAccountDialog(context, ref);
                },
                child: const Text('open miniflux'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _MemoryAccountStore extends AccountStore {
  _MemoryAccountStore(this.state);

  AccountsState state;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState state) async {
    this.state = state;
  }
}

class _FakeCredentialStore extends CredentialStore {
  final basicAuth = <String, ({String username, String password})>{};
  final deletedApiTokens = <String>{};

  @override
  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return basicAuth[accountId];
  }

  @override
  Future<void> setBasicAuth(
    String accountId,
    AccountType type, {
    required String username,
    required String password,
  }) async {
    basicAuth[accountId] = (username: username, password: password);
  }

  @override
  Future<void> deleteApiToken(String accountId, AccountType type) async {
    deletedApiTokens.add(accountId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPlatform;
  });

  for (final testCase
      in <
        ({
          String name,
          Key openKey,
          String accountType,
          String authMode,
          String host,
          String path,
          String baseUrl,
          String secret,
        })
      >[
        (
          name: 'Miniflux',
          openKey: const Key('open_miniflux'),
          accountType: 'miniflux',
          authMode: 'apiToken',
          host: 'miniflux.example.com',
          path: '/root',
          baseUrl: 'https://miniflux.example.com/root?token=query-secret#frag',
          secret: 'api-token-secret',
        ),
        (
          name: 'Fever',
          openKey: const Key('open_fever'),
          accountType: 'fever',
          authMode: 'apiKey',
          host: 'fever.example.com',
          path: '/api',
          baseUrl: 'https://fever.example.com/api?token=query-secret#frag',
          secret: 'api-key-secret',
        ),
      ]) {
    testWidgets('${testCase.name} add account failure logs sanitized context', (
      tester,
    ) async {
      await _withTestLogger(tester, () async {
        await pumpLocalizedTestApp(
          tester,
          home: _buildLauncher(),
          overrides: [
            accountStoreProvider.overrideWithValue(_ThrowingAccountStore()),
          ],
        );

        await tester.tap(find.byKey(testCase.openKey));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), testCase.baseUrl);
        await tester.enterText(find.byType(TextField).at(2), testCase.secret);
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();

        final contents = await tester.runAsync(_readActiveLog);
        expect(contents, isNotNull);
        final log = contents!;
        expect(log, contains('[W] [account] Add remote account failed'));
        expect(log, contains('operation=addRemoteAccount'));
        expect(log, contains('accountType=${testCase.accountType}'));
        expect(log, contains('authMode=${testCase.authMode}'));
        expect(log, contains('host=${testCase.host}'));
        expect(log, contains('path=${testCase.path}'));
        expect(log, isNot(contains(testCase.secret)));
        expect(log, isNot(contains('query-secret')));
        expect(log, isNot(contains('#frag')));
      });
    });
  }

  testWidgets('Google Reader dialog probes and stores resolved profile', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1);
    final store = _MemoryAccountStore(
      AccountsState(
        version: AccountStore.currentVersion,
        activeAccountId: 'local',
        accounts: [
          Account(
            id: 'local',
            type: AccountType.local,
            name: 'Local',
            isPrimary: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    final credentials = _FakeCredentialStore();

    await pumpLocalizedTestApp(
      tester,
      home: _buildLauncher(),
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        credentialStoreProvider.overrideWithValue(credentials),
        dioProvider.overrideWithValue(_googleReaderProbeDio()),
      ],
    );

    await tester.tap(find.byKey(const Key('open_google_reader')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(1),
      'https://rss.example.com/api/greader.php/reader/api/0',
    );
    await tester.enterText(find.byType(TextField).at(2), 'reader-user');
    await tester.enterText(find.byType(TextField).at(3), 'reader-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final account = store.state.accounts.singleWhere(
      (account) => account.type == AccountType.googleReader,
    );
    expect(account.profileId, GoogleReaderProviderProfiles.freshRssId);
    expect(account.baseUrl, 'https://rss.example.com/');
    expect(store.state.activeAccountId, account.id);
    expect(credentials.basicAuth[account.id]?.username, 'reader-user');
    expect(credentials.basicAuth[account.id]?.password, 'reader-password');
    expect(credentials.deletedApiTokens, contains(account.id));
  });

  testWidgets('Google Reader connection dialog tests without persisting', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1);
    final reader = Account(
      id: 'reader',
      type: AccountType.googleReader,
      name: 'FreshRSS',
      baseUrl: 'https://rss.example.com',
      profileId: GoogleReaderProviderProfiles.freshRssId,
      createdAt: now,
      updatedAt: now,
    );
    final store = _MemoryAccountStore(
      AccountsState(
        version: AccountStore.currentVersion,
        activeAccountId: reader.id,
        accounts: [reader],
      ),
    );
    final credentials = _FakeCredentialStore();
    credentials.basicAuth[reader.id] = (
      username: 'reader-user',
      password: 'reader-password',
    );

    await pumpLocalizedTestApp(
      tester,
      home: _buildLauncher(),
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        credentialStoreProvider.overrideWithValue(credentials),
        dioProvider.overrideWithValue(_googleReaderProbeDio()),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_google_reader_edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Test connection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Connected: FreshRSS'), findsOneWidget);
    expect(store.state.accounts.single.baseUrl, 'https://rss.example.com');
    expect(credentials.basicAuth[reader.id]?.username, 'reader-user');
    expect(credentials.deletedApiTokens, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Google Reader connection dialog saves normalized URL and existing password',
    (tester) async {
      final now = DateTime.utc(2026, 1, 1);
      final reader = Account(
        id: 'reader',
        type: AccountType.googleReader,
        name: 'FreshRSS',
        baseUrl: 'https://old.example.com',
        profileId: GoogleReaderProviderProfiles.freshRssId,
        createdAt: now,
        updatedAt: now,
      );
      final store = _MemoryAccountStore(
        AccountsState(
          version: AccountStore.currentVersion,
          activeAccountId: reader.id,
          accounts: [reader],
        ),
      );
      final credentials = _FakeCredentialStore();
      credentials.basicAuth[reader.id] = (
        username: 'old-user',
        password: 'old-password',
      );

      await pumpLocalizedTestApp(
        tester,
        home: _buildLauncher(),
        overrides: [
          accountStoreProvider.overrideWithValue(store),
          credentialStoreProvider.overrideWithValue(credentials),
          dioProvider.overrideWithValue(_googleReaderProbeDio()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_google_reader_edit')));
      await tester.pumpAndSettle();
      final usernameField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(usernameField.controller?.text, 'old-user');
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://rss.example.com/api/greader.php/reader/api/0',
      );
      await tester.enterText(find.byType(TextField).at(1), 'new-user');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final updated = store.state.accounts.single;
      expect(updated.baseUrl, 'https://rss.example.com/');
      expect(updated.profileId, GoogleReaderProviderProfiles.freshRssId);
      expect(credentials.basicAuth[reader.id]?.username, 'new-user');
      expect(credentials.basicAuth[reader.id]?.password, 'old-password');
      expect(credentials.deletedApiTokens, contains(reader.id));
    },
  );

  testWidgets('Google Reader connection failure logs sanitized context', (
    tester,
  ) async {
    await _withTestLogger(tester, () async {
      final now = DateTime.utc(2026, 1, 1);
      final reader = Account(
        id: 'reader',
        type: AccountType.googleReader,
        name: 'Reader',
        baseUrl: 'https://reader.example.com/root',
        profileId: GoogleReaderProviderProfiles.genericId,
        createdAt: now,
        updatedAt: now,
      );
      final store = _MemoryAccountStore(
        AccountsState(
          version: AccountStore.currentVersion,
          activeAccountId: reader.id,
          accounts: [reader],
        ),
      );
      final credentials = _FakeCredentialStore();
      credentials.basicAuth[reader.id] = (
        username: 'user-secret',
        password: 'password-secret',
      );

      await pumpLocalizedTestApp(
        tester,
        home: _buildLauncher(),
        overrides: [
          accountStoreProvider.overrideWithValue(store),
          credentialStoreProvider.overrideWithValue(credentials),
          dioProvider.overrideWithValue(_failingGoogleReaderProbeDio()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_google_reader_edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://reader.example.com/root?token=query-secret#frag',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Test connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final contents = await tester.runAsync(_readActiveLog);
      final log = contents!;
      expect(
        log,
        contains('[W] [account] Google Reader account connection failed'),
      );
      expect(log, contains('operation=testGoogleReaderConnection'));
      expect(log, contains('probeOperation=clientLogin'));
      expect(log, contains('profileId=googleReaderGeneric'));
      expect(log, contains('host=reader.example.com'));
      expect(log, contains('path=/root/accounts/ClientLogin'));
      expect(log, isNot(contains('password-secret')));
      expect(log, isNot(contains('query-secret')));
      expect(log, isNot(contains('#frag')));
      expect(
        store.state.accounts.single.baseUrl,
        'https://reader.example.com/root',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    });
  });
}

Dio _googleReaderProbeDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final data = switch ((options.method, options.uri.path)) {
          ('POST', '/api/greader.php/accounts/ClientLogin') =>
            'Auth=login-token\n',
          ('GET', '/api/greader.php/reader/api/0/user-info') => {
            'userName': 'Reader User',
          },
          ('GET', '/api/greader.php/reader/api/0/token') => 'write-token',
          ('GET', '/api/greader.php/reader/api/0/stream/items/ids') => {
            'itemRefs': <Object?>[],
          },
          _ => throw StateError(
            'Unexpected request: ${options.method} ${options.uri}',
          ),
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

Dio _failingGoogleReaderProbeDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 401,
            ),
          ),
        );
      },
    ),
  );
  return dio;
}

Future<T> _withTestLogger<T>(
  WidgetTester tester,
  Future<T> Function() body,
) async {
  late PathProviderPlatform previousPlatform;
  late Directory tempDir;
  await tester.runAsync(() async {
    previousPlatform = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_add_account_dialog_test_',
    );
    final documents = await Directory(
      '${tempDir.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir.path}/cache',
    ).create(recursive: true);
    final temporary = await Directory(
      '${tempDir.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documents.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
    await AppLogger.resetForTests();
    await AppLogger.ensureInitialized();
  });
  try {
    return await body();
  } finally {
    await tester.runAsync(() async {
      await AppLogger.resetForTests();
      PathManager.resetForTests();
      PathProviderPlatform.instance = previousPlatform;
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // ignore: best-effort cleanup
      }
    });
  }
}

Future<String> _readActiveLog() async {
  final logFile = await AppLogger.getActiveLogFile();
  await AppLogger.resetForTests();
  return logFile!.readAsString();
}
