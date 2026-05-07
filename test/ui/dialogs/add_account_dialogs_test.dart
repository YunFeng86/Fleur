import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/logging/app_logger.dart';
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
