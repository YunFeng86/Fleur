import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
import 'package:fleur/services/persistence/durable_json_store.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  late Directory tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_account_cleanup_');
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
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: documents.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPlatform;
    PathManager.resetForTests();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'deleting an account removes snapshots without unlinking the durable lock',
    () async {
      const accountId = 'remote/account';
      final stateDir = await PathManager.getStateDir();
      final separator = Platform.pathSeparator;
      final primaryPath = '${stateDir.path}${separator}outbox_$accountId.json';
      final snapshots = <File>[
        File(primaryPath),
        File('$primaryPath.tmp'),
        File('$primaryPath.bak'),
      ];
      final durableLock = File('$primaryPath.lock');
      final legacyLock = File(
        '${stateDir.path}${separator}mutex_outbox_remote_account.lock',
      );
      for (final file in [...snapshots, durableLock, legacyLock]) {
        await file.create(recursive: true);
        await file.writeAsString('state');
      }

      await AccountCleanupService(
        credentials: _FakeCredentialStore(),
        databaseLifecycle: _FakeAccountDatabaseLifecycle(),
      ).deleteAccountData(_remoteAccount(accountId));

      for (final file in snapshots) {
        expect(await file.exists(), isFalse, reason: file.path);
      }
      expect(await durableLock.exists(), isTrue);
      expect(await legacyLock.exists(), isFalse);
    },
  );

  test(
    'cleanup waits for an in-flight outbox commit before deleting it',
    () async {
      const accountId = 'remote';
      final fileSystem = _BlockingOutboxFileSystem();
      final outbox = OutboxStore(fileSystem: fileSystem);
      final write = outbox.save(accountId, <OutboxAction>[
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 1,
          value: true,
          createdAt: DateTime.utc(2026, 7, 22),
        ),
      ]);
      await fileSystem.replaceStarted.future;

      var cleanupCompleted = false;
      final cleanup =
          AccountCleanupService(
                credentials: _FakeCredentialStore(),
                outbox: outbox,
                databaseLifecycle: _FakeAccountDatabaseLifecycle(),
              )
              .deleteAccountData(_remoteAccount(accountId))
              .then((_) => cleanupCompleted = true);
      await Future<void>.delayed(Duration.zero);

      expect(cleanupCompleted, isFalse);

      fileSystem.allowReplace.complete();
      await write;
      await cleanup;

      expect(await outbox.load(accountId), isEmpty);
      final stateDir = await PathManager.getStateDir();
      final primaryPath =
          '${stateDir.path}${Platform.pathSeparator}outbox_$accountId.json';
      expect(await File(primaryPath).exists(), isFalse);
      expect(await File('$primaryPath.tmp').exists(), isFalse);
      expect(await File('$primaryPath.bak').exists(), isFalse);
      expect(await File('$primaryPath.lock').exists(), isTrue);
    },
  );

  test('database cleanup failure preserves outbox state', () async {
    const accountId = 'remote';
    final outbox = OutboxStore();
    await outbox.save(accountId, <OutboxAction>[
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 7, 22),
      ),
    ]);

    await expectLater(
      AccountCleanupService(
        credentials: _FakeCredentialStore(),
        outbox: outbox,
        databaseLifecycle: _FakeAccountDatabaseLifecycle(
          result: const AccountDatabaseDeletionBlocked(
            reason: AccountDatabaseDeletionBlockReason.activeLease,
            supportCode: 'delete:remote:activeLease',
          ),
        ),
      ).deleteAccountData(_remoteAccount(accountId)),
      throwsStateError,
    );

    expect(await outbox.load(accountId), hasLength(1));
  });
}

Account _remoteAccount(String accountId) {
  final now = DateTime.utc(2026, 7, 22);
  return Account(
    id: accountId,
    type: AccountType.miniflux,
    name: 'Remote',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<void> deleteApiToken(String accountId, AccountType type) async {}

  @override
  Future<void> deleteBasicAuth(String accountId, AccountType type) async {}
}

class _FakeAccountDatabaseLifecycle implements AccountDatabaseLifecycle {
  _FakeAccountDatabaseLifecycle({AccountDatabaseDeletionResult? result})
    : _result =
          result ?? const AccountDatabaseDeleted(auditId: 'test-deletion');

  final AccountDatabaseDeletionResult _result;

  @override
  Future<AccountDatabaseAcquireResult> acquireExisting(
    AccountDatabaseRef account,
  ) async => AccountDatabaseAccessFailure(
    kind: AccountDatabaseAccessFailureKind.dataMissing,
    accountId: account.accountId,
    supportCode: 'test:not-used',
  );

  @override
  Future<AccountDatabaseAcquireResult> initialize(
    AccountDatabaseInitialization intent,
  ) async => AccountDatabaseAccessFailure(
    kind: AccountDatabaseAccessFailureKind.dataMissing,
    accountId: intent.accountId,
    supportCode: 'test:not-used',
  );

  @override
  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  ) async => _result;
}

class _BlockingOutboxFileSystem implements DurableFileSystem {
  final IoDurableFileSystem _delegate = const IoDurableFileSystem();
  final Completer<void> replaceStarted = Completer<void>();
  final Completer<void> allowReplace = Completer<void>();
  var _didBlock = false;

  @override
  Future<void> createParentDirectory(String filePath) {
    return _delegate.createParentDirectory(filePath);
  }

  @override
  Future<void> delete(String path) => _delegate.delete(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<void> move(String sourcePath, String destinationPath) async {
    if (!_didBlock && sourcePath.endsWith('.tmp')) {
      _didBlock = true;
      replaceStarted.complete();
      await allowReplace.future;
    }
    await _delegate.move(sourcePath, destinationPath);
  }

  @override
  Future<String> readAsString(String path) => _delegate.readAsString(path);

  @override
  Future<void> writeAsString(String path, String contents) {
    return _delegate.writeAsString(path, contents);
  }
}
