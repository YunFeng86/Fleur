import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/db/isar_db.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_lifecycle.dart';

void main() {
  const intent = AccountDatabaseDeletionIntent(
    accountId: 'remote',
    operationId: 'delete-operation',
  );

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

Account _remoteAccount() {
  final now = DateTime.utc(2026, 7, 23);
  return Account(
    id: 'remote',
    type: AccountType.miniflux,
    name: 'Remote',
    dbName: 'remote_database',
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
