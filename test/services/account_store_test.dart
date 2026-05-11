import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  Directory? tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_account_store_');
    final docs = await Directory(
      '${tempDir!.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir!.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir!.path}/cache',
    ).create(recursive: true);
    final temporary = await Directory(
      '${tempDir!.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
  });

  tearDown(() async {
    PathManager.resetForTests();
    PathProviderPlatform.instance = originalPlatform;
    final dir = tempDir;
    tempDir = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('AccountsState.fromJson skips malformed account entries', () {
    final now = DateTime.utc(2026, 1, 1).toIso8601String();

    final state = AccountsState.fromJson(<String, Object?>{
      'version': AccountStore.currentVersion,
      'activeAccountId': 'valid-account',
      'accounts': <Object?>[
        <String, Object?>{
          'id': 'valid-account',
          'type': 'local',
          'name': 'Valid',
          'isPrimary': true,
          'createdAt': now,
          'updatedAt': now,
        },
        <String, Object?>{
          'id': 'broken-account',
          'type': 'unknown',
          'name': 'Broken',
          'createdAt': now,
          'updatedAt': now,
        },
      ],
    });

    expect(state.accounts, hasLength(1));
    expect(state.accounts.single.id, 'valid-account');
    expect(state.activeAccountId, 'valid-account');
  });

  test(
    'AccountStore keeps valid accounts when active id is malformed',
    () async {
      final now = DateTime.utc(2026, 1, 1).toIso8601String();
      final stateDir = await PathManager.getStateDir();
      final file = File(
        '${stateDir.path}${Platform.pathSeparator}accounts.json',
      );
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'version': AccountStore.currentVersion,
          'activeAccountId': 42,
          'accounts': <Object?>[
            <String, Object?>{
              'id': 'valid-account',
              'type': 'local',
              'name': 'Valid',
              'isPrimary': true,
              'createdAt': now,
              'updatedAt': now,
            },
          ],
        }),
      );

      final state = await AccountStore().loadOrCreate();

      expect(state.accounts, hasLength(1));
      expect(state.accounts.single.id, 'valid-account');
      expect(state.activeAccountId, 'valid-account');
    },
  );

  test('AccountStore keeps valid accounts when version is malformed', () async {
    final now = DateTime.utc(2026, 1, 1).toIso8601String();
    final stateDir = await PathManager.getStateDir();
    final file = File('${stateDir.path}${Platform.pathSeparator}accounts.json');
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 'broken',
        'activeAccountId': 'valid-account',
        'accounts': <Object?>[
          <String, Object?>{
            'id': 'valid-account',
            'type': 'local',
            'name': 'Valid',
            'isPrimary': true,
            'createdAt': now,
            'updatedAt': now,
          },
        ],
      }),
    );

    final state = await AccountStore().loadOrCreate();

    expect(state.accounts, hasLength(1));
    expect(state.accounts.single.id, 'valid-account');
    expect(state.activeAccountId, 'valid-account');
    expect(state.version, AccountStore.currentVersion);
  });
}
