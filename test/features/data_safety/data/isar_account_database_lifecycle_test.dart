import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/db/isar_db.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_lifecycle.dart';
import 'package:isar_community/isar.dart';

void main() {
  const intent = AccountDatabaseDeletionIntent(
    accountId: 'remote',
    operationId: 'delete-operation',
  );

  group('database acquisition', () {
    test('acquires an existing initialized account database', () async {
      final openedModes = <AccountDbOpenMode>[];
      final isar = _FakeIsar();
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(_stateWith(_remoteAccount())),
        sessions: _sessionsOpening(isar, openedModes: openedModes),
      );

      final result = await lifecycle.acquireExisting(
        const AccountDatabaseRef(accountId: 'remote'),
      );

      expect(
        result,
        isA<AccountDatabaseReady>()
            .having((value) => value.initializedNow, 'initializedNow', isFalse)
            .having(
              (value) => value.lease.accountId,
              'lease.accountId',
              'remote',
            ),
      );
      expect(openedModes, <AccountDbOpenMode>[AccountDbOpenMode.existing]);

      await (result as AccountDatabaseReady).lease.release();
    });

    test('requires initialization for a pending existing account', () async {
      var openCalls = 0;
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(
          _stateWith(_remoteAccount(databaseInitialized: false)),
        ),
        sessions: _sessionsWithOpener((target, mode) async {
          openCalls++;
          return _FakeIsar();
        }),
      );

      final result = await lifecycle.acquireExisting(
        const AccountDatabaseRef(accountId: 'remote'),
      );

      expect(
        result,
        isA<AccountDatabaseAccessFailure>()
            .having(
              (value) => value.kind,
              'kind',
              AccountDatabaseAccessFailureKind.initializationRequired,
            )
            .having(
              (value) => value.supportCode,
              'supportCode',
              'database-access:remote:initializationRequired',
            ),
      );
      expect(openCalls, 0);
    });

    test('initializes a pending account and marks the result', () async {
      final openedModes = <AccountDbOpenMode>[];
      final isar = _FakeIsar();
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(
          _stateWith(_remoteAccount(databaseInitialized: false)),
        ),
        sessions: _sessionsOpening(isar, openedModes: openedModes),
      );

      final result = await lifecycle.initialize(
        const AccountDatabaseInitialization(
          accountId: 'remote',
          operationId: 'initialize-remote',
        ),
      );

      expect(
        result,
        isA<AccountDatabaseReady>()
            .having((value) => value.initializedNow, 'initializedNow', isTrue)
            .having(
              (value) => value.lease.accountId,
              'lease.accountId',
              'remote',
            ),
      );
      expect(openedModes, <AccountDbOpenMode>[AccountDbOpenMode.initialize]);

      await (result as AccountDatabaseReady).lease.release();
    });

    test('reports missing account data without opening a database', () async {
      var openCalls = 0;
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(_primaryOnlyState()),
        sessions: _sessionsWithOpener((target, mode) async {
          openCalls++;
          return _FakeIsar();
        }),
      );

      final result = await lifecycle.acquireExisting(
        const AccountDatabaseRef(accountId: 'missing'),
      );

      expect(
        result,
        isA<AccountDatabaseAccessFailure>()
            .having(
              (value) => value.kind,
              'kind',
              AccountDatabaseAccessFailureKind.dataMissing,
            )
            .having((value) => value.accountId, 'accountId', 'missing'),
      );
      expect(openCalls, 0);
    });

    test(
      'maps account metadata lookup failures to storage unavailable',
      () async {
        final lifecycle = IsarAccountDatabaseLifecycle(
          findAccount: (accountId) async {
            throw const FileSystemException('account metadata unavailable');
          },
          sessions: _sessionsOpening(_FakeIsar()),
        );

        final result = await lifecycle.acquireExisting(
          const AccountDatabaseRef(accountId: 'remote'),
        );

        expect(
          result,
          isA<AccountDatabaseAccessFailure>().having(
            (value) => value.kind,
            'kind',
            AccountDatabaseAccessFailureKind.storageUnavailable,
          ),
        );
      },
    );

    test('maps target filesystem failures to storage unavailable', () async {
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(_stateWith(_remoteAccount())),
        sessions: _sessionsWithOpener((target, mode) async {
          throw const FileSystemException('database directory unavailable');
        }),
      );

      final result = await lifecycle.acquireExisting(
        const AccountDatabaseRef(accountId: 'remote'),
      );

      expect(
        result,
        isA<AccountDatabaseAccessFailure>().having(
          (value) => value.kind,
          'kind',
          AccountDatabaseAccessFailureKind.storageUnavailable,
        ),
      );
    });

    for (final testCase
        in <
          ({
            DbOpenFailureKind source,
            AccountDatabaseAccessFailureKind expected,
          })
        >[
          (
            source: DbOpenFailureKind.transient,
            expected: AccountDatabaseAccessFailureKind.blockedByAnotherProcess,
          ),
          (
            source: DbOpenFailureKind.ownershipMismatch,
            expected: AccountDatabaseAccessFailureKind.ownershipMismatch,
          ),
          (
            source: DbOpenFailureKind.environmental,
            expected: AccountDatabaseAccessFailureKind.storageUnavailable,
          ),
          (
            source: DbOpenFailureKind.recoveryRequired,
            expected: AccountDatabaseAccessFailureKind.recoveryRequired,
          ),
          (
            source: DbOpenFailureKind.dataMissing,
            expected: AccountDatabaseAccessFailureKind.dataMissing,
          ),
        ]) {
      test('maps ${testCase.source.name} acquisition failures to '
          '${testCase.expected.name}', () async {
        final lifecycle = IsarAccountDatabaseLifecycle(
          findAccount: _findAccountIn(_stateWith(_remoteAccount())),
          sessions: _sessionsWithOpener((target, mode) async {
            throw _failure(testCase.source);
          }),
        );

        final result = await lifecycle.acquireExisting(
          const AccountDatabaseRef(accountId: 'remote'),
        );

        expect(
          result,
          isA<AccountDatabaseAccessFailure>()
              .having((value) => value.kind, 'kind', testCase.expected)
              .having(
                (value) => value.supportCode,
                'supportCode',
                'database-access:remote:${testCase.expected.name}',
              ),
        );
      });
    }

    test(
      'maps unexpected opener or migration errors to migrationFailed',
      () async {
        final lifecycle = IsarAccountDatabaseLifecycle(
          findAccount: _findAccountIn(_stateWith(_remoteAccount())),
          sessions: _sessionsWithOpener((target, mode) async {
            throw StateError('migration failed after opening');
          }),
        );

        final result = await lifecycle.acquireExisting(
          const AccountDatabaseRef(accountId: 'remote'),
        );

        expect(
          result,
          isA<AccountDatabaseAccessFailure>()
              .having(
                (value) => value.kind,
                'kind',
                AccountDatabaseAccessFailureKind.migrationFailed,
              )
              .having(
                (value) => value.supportCode,
                'supportCode',
                'database-access:remote:migrationFailed',
              ),
        );
      },
    );

    test('releases the underlying Isar session exactly once', () async {
      final isar = _FakeIsar();
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(_stateWith(_remoteAccount())),
        sessions: _sessionsOpening(isar),
      );
      final result = await lifecycle.acquireExisting(
        const AccountDatabaseRef(accountId: 'remote'),
      );
      final ready = result as AccountDatabaseReady;

      await ready.lease.release();
      await ready.lease.release();

      expect(isar.closeCalls, 1);
      expect(isar.isOpen, isFalse);
    });
  });

  test('returns deleted when the account database is removed', () async {
    final sessions = _FakeAccountDbSessionManager(results: <Object>[true]);
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: _findAccountIn(_stateWith(_remoteAccount())),
      sessions: sessions,
    );

    final result = await lifecycle.deleteForAccountRemoval(intent);

    expect(result, isA<AccountDatabaseDeleted>());
    expect((result as AccountDatabaseDeleted).auditId, intent.operationId);
    expect(sessions.calls, 1);
  });

  test('returns already deleted when the database file is absent', () async {
    final sessions = _FakeAccountDbSessionManager(results: <Object>[false]);
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: _findAccountIn(_stateWith(_remoteAccount())),
      sessions: sessions,
    );

    final result = await lifecycle.deleteForAccountRemoval(intent);

    expect(result, isA<AccountDatabaseAlreadyDeleted>());
    expect(
      (result as AccountDatabaseAlreadyDeleted).auditId,
      intent.operationId,
    );
    expect(sessions.calls, 1);
  });

  test('returns already deleted when the account no longer exists', () async {
    final sessions = _FakeAccountDbSessionManager();
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: _findAccountIn(_primaryOnlyState()),
      sessions: sessions,
    );

    final result = await lifecycle.deleteForAccountRemoval(intent);

    expect(result, isA<AccountDatabaseAlreadyDeleted>());
    expect(sessions.calls, 0);
  });

  test('blocks deletion of the primary account before touching Isar', () async {
    final sessions = _FakeAccountDbSessionManager();
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: _findAccountIn(_primaryOnlyState()),
      sessions: sessions,
    );

    final result = await lifecycle.deleteForAccountRemoval(
      const AccountDatabaseDeletionIntent(
        accountId: 'local',
        operationId: 'delete-primary',
      ),
    );

    expect(
      result,
      isA<AccountDatabaseDeletionBlocked>().having(
        (value) => value.reason,
        'reason',
        AccountDatabaseDeletionBlockReason.primaryAccount,
      ),
    );
    expect(sessions.calls, 0);
  });

  test('retries transient failures then reports an active lease', () async {
    final transient = _failure(DbOpenFailureKind.transient);
    final sessions = _FakeAccountDbSessionManager(
      results: <Object>[transient, transient, transient, transient, transient],
    );
    final delays = <Duration>[];
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: _findAccountIn(_stateWith(_remoteAccount())),
      sessions: sessions,
      sleep: (delay) async => delays.add(delay),
    );

    final result = await lifecycle.deleteForAccountRemoval(intent);

    expect(
      result,
      isA<AccountDatabaseDeletionBlocked>()
          .having(
            (value) => value.reason,
            'reason',
            AccountDatabaseDeletionBlockReason.activeLease,
          )
          .having(
            (value) => value.supportCode,
            'supportCode',
            'delete-operation:activeLease',
          ),
    );
    expect(sessions.calls, 5);
    expect(delays, const <Duration>[
      Duration(milliseconds: 150),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ]);
  });

  for (final testCase
      in <
        ({DbOpenFailureKind kind, AccountDatabaseDeletionBlockReason reason})
      >[
        (
          kind: DbOpenFailureKind.ownershipMismatch,
          reason: AccountDatabaseDeletionBlockReason.ownershipMismatch,
        ),
        (
          kind: DbOpenFailureKind.environmental,
          reason: AccountDatabaseDeletionBlockReason.storageUnavailable,
        ),
        (
          kind: DbOpenFailureKind.dataMissing,
          reason: AccountDatabaseDeletionBlockReason.storageUnavailable,
        ),
        (
          kind: DbOpenFailureKind.recoveryRequired,
          reason: AccountDatabaseDeletionBlockReason.recoveryRequired,
        ),
      ]) {
    test('maps ${testCase.kind.name} to ${testCase.reason.name}', () async {
      final lifecycle = IsarAccountDatabaseLifecycle(
        findAccount: _findAccountIn(_stateWith(_remoteAccount())),
        sessions: _FakeAccountDbSessionManager(
          results: <Object>[_failure(testCase.kind)],
        ),
      );

      final result = await lifecycle.deleteForAccountRemoval(intent);

      expect(
        result,
        isA<AccountDatabaseDeletionBlocked>()
            .having((value) => value.reason, 'reason', testCase.reason)
            .having(
              (value) => value.supportCode,
              'supportCode',
              'delete-operation:${testCase.reason.name}',
            ),
      );
    });
  }
}

DbOpenFailure _failure(DbOpenFailureKind kind) {
  return DbOpenFailure(
    kind: kind,
    directory: '/test/database',
    name: 'remote_database',
    error: StateError('injected ${kind.name} failure'),
  );
}

Account _remoteAccount({bool databaseInitialized = true}) {
  final now = DateTime.utc(2026, 7, 23);
  return Account(
    id: 'remote',
    type: AccountType.miniflux,
    name: 'Remote',
    dbName: 'remote_database',
    databaseInitialized: databaseInitialized,
    createdAt: now,
    updatedAt: now,
  );
}

AccountsState _stateWith(Account remote) {
  final primary = _primaryAccount();
  return AccountsState(
    version: AccountStore.currentVersion,
    activeAccountId: primary.id,
    accounts: <Account>[primary, remote],
  );
}

AccountsState _primaryOnlyState() {
  final primary = _primaryAccount();
  return AccountsState(
    version: AccountStore.currentVersion,
    activeAccountId: primary.id,
    accounts: <Account>[primary],
  );
}

Account _primaryAccount() {
  final now = DateTime.utc(2026, 7, 23);
  return Account(
    id: 'local',
    type: AccountType.local,
    name: 'Local',
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );
}

AccountDatabaseAccountLookup _findAccountIn(AccountsState state) {
  return (accountId) async => state.findById(accountId);
}

AccountDbSessionManager _sessionsOpening(
  Isar isar, {
  List<AccountDbOpenMode>? openedModes,
}) {
  return _sessionsWithOpener((target, mode) async {
    openedModes?.add(mode);
    return isar;
  });
}

AccountDbSessionManager _sessionsWithOpener(AccountDbTargetOpener opener) {
  return AccountDbSessionManager(
    resolveTarget: ({required accountId, dbName, required isPrimary}) async {
      return AccountDbTarget(
        accountId: accountId,
        directory: '/test/database',
        name: dbName ?? 'fleur_$accountId',
        isPrimary: isPrimary,
      );
    },
    openTarget: opener,
  );
}

class _FakeIsar extends Fake implements Isar {
  var closeCalls = 0;
  var open = true;

  @override
  bool get isOpen => open;

  @override
  Future<bool> close({bool deleteFromDisk = false}) async {
    closeCalls++;
    open = false;
    return true;
  }
}

class _FakeAccountDbSessionManager extends AccountDbSessionManager {
  _FakeAccountDbSessionManager({List<Object> results = const <Object>[]})
    : _results = List<Object>.of(results);

  final List<Object> _results;
  int calls = 0;

  @override
  Future<bool> deleteIdleForAccount({
    required String accountId,
    String? dbName,
    required bool isPrimary,
  }) async {
    calls++;
    final result = _results.removeAt(0);
    if (result is Error || result is Exception) throw result;
    return result as bool;
  }
}
