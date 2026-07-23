import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/app/account_gate.dart';
import 'package:fleur/db/isar_db.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_lifecycle.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
import 'package:fleur/services/data_integrity_startup_service.dart';

import '../test_utils/critical_workflow_test_support.dart';

class _FakeAccountStore extends AccountStore {
  _FakeAccountStore(this.state);

  AccountsState state;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState next) async {
    state = next;
  }
}

class _FakeIsar extends Fake implements Isar {
  _FakeIsar({required this.name, required this.directory});

  @override
  final String name;

  @override
  final String directory;

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

class _ControlledDataIntegrityStartupService
    extends DataIntegrityStartupService {
  final Map<String, Completer<void>> runs = {};

  @override
  Future<void> runIfNeeded(Isar isar) {
    return runs.putIfAbsent(isar.name, Completer<void>.new).future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does not acquire DB again on resize while open is pending', (
    tester,
  ) async {
    final account = buildTestAccount(
      id: 'account-a',
      type: AccountType.local,
      isPrimary: false,
    );
    final state = AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: account.id,
      accounts: [account],
    );
    final openCompleter = Completer<Isar>();
    var openCalls = 0;
    final manager = AccountDbSessionManager(
      resolveTarget: ({required accountId, dbName, required isPrimary}) async {
        return AccountDbTarget(
          accountId: accountId,
          directory: '/tmp/fleur-db',
          name: 'fleur_$accountId',
          isPrimary: isPrimary,
        );
      },
      openTarget: (target, mode) {
        openCalls++;
        return openCompleter.future;
      },
    );

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountStoreProvider.overrideWithValue(_FakeAccountStore(state)),
        ],
        child: MaterialApp(
          home: AccountGate(
            databaseLifecycle: _ManagerBackedLifecycle(manager),
          ),
        ),
      ),
    );
    await tester.pump();

    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    tester.view.physicalSize = const Size(1300, 900);
    await tester.pump();

    expect(openCalls, 1);
  });

  testWidgets('initializes a pending account and persists completion', (
    tester,
  ) async {
    final account = buildTestAccount(
      id: 'new-account',
      type: AccountType.local,
      databaseInitialized: false,
    );
    final store = _FakeAccountStore(
      AccountsState(
        version: AccountStore.currentVersion,
        activeAccountId: account.id,
        accounts: [account],
      ),
    );
    AccountDbOpenMode? requestedMode;
    final isar = _FakeIsar(
      name: 'fleur_${account.id}',
      directory: '/tmp/fleur-db',
    );
    final openCompleter = Completer<Isar>();
    final manager = AccountDbSessionManager(
      resolveTarget: ({required accountId, dbName, required isPrimary}) async {
        return AccountDbTarget(
          accountId: accountId,
          directory: '/tmp/fleur-db',
          name: 'fleur_$accountId',
          isPrimary: isPrimary,
        );
      },
      openTarget: (target, mode) async {
        requestedMode = mode;
        return openCompleter.future;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: AccountGate(
            databaseLifecycle: _ManagerBackedLifecycle(manager),
          ),
        ),
      ),
    );
    openCompleter.complete(isar);
    await tester.idle();

    expect(requestedMode, AccountDbOpenMode.initialize);
    expect(store.state.accounts.single.databaseInitialized, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
  });

  testWidgets('switching accounts releases the previous DB lease', (
    tester,
  ) async {
    final first = buildTestAccount(
      id: 'account-a',
      type: AccountType.local,
      isPrimary: false,
    );
    final second = buildTestAccount(
      id: 'account-b',
      type: AccountType.local,
      isPrimary: false,
    );
    final state = AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: first.id,
      accounts: [first, second],
    );
    final store = _FakeAccountStore(state);
    final firstIsar = _FakeIsar(
      name: 'fleur_${first.id}',
      directory: '/tmp/fleur-db',
    );
    final secondIsar = _FakeIsar(
      name: 'fleur_${second.id}',
      directory: '/tmp/fleur-db',
    );
    final maintenance = _ControlledDataIntegrityStartupService();
    final openCompleters = <String, Completer<Isar>>{
      first.id: Completer<Isar>(),
      second.id: Completer<Isar>(),
    };
    final manager = AccountDbSessionManager(
      resolveTarget: ({required accountId, dbName, required isPrimary}) async {
        return AccountDbTarget(
          accountId: accountId,
          directory: '/tmp/fleur-db',
          name: 'fleur_$accountId',
          isPrimary: isPrimary,
        );
      },
      openTarget: (target, mode) async {
        return openCompleters[target.accountId]!.future;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: AccountGate(
            databaseLifecycle: _ManagerBackedLifecycle(manager),
            dataIntegrityStartupService: maintenance,
          ),
        ),
      ),
    );
    await tester.pump();
    openCompleters[first.id]!.complete(firstIsar);
    await tester.idle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountGate)),
    );
    await container
        .read(accountsControllerProvider.notifier)
        .setActive(second.id);
    await tester.idle();
    openCompleters[second.id]!.complete(secondIsar);
    await tester.idle();

    expect(firstIsar.closeCalls, 0);
    maintenance.runs[firstIsar.name]!.complete();
    await tester.idle();
    expect(firstIsar.closeCalls, 1);
    expect(firstIsar.isOpen, false);
    expect(secondIsar.closeCalls, 0);

    maintenance.runs[secondIsar.name]!.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
    expect(secondIsar.closeCalls, 1);
  });
}

class _ManagerBackedLifecycle implements AccountDatabaseLifecycle {
  _ManagerBackedLifecycle(this.manager);

  final AccountDbSessionManager manager;

  @override
  Future<AccountDatabaseAcquireResult> acquireExisting(
    AccountDatabaseRef account,
  ) async {
    final lease = await manager.acquireExistingForAccount(
      accountId: account.accountId,
      isPrimary: false,
    );
    return AccountDatabaseReady(
      lease: IsarAccountDatabaseLease(
        accountId: account.accountId,
        lease: lease,
      ),
      initializedNow: false,
    );
  }

  @override
  Future<AccountDatabaseAcquireResult> initialize(
    AccountDatabaseInitialization intent,
  ) async {
    final lease = await manager.initializeForAccount(
      accountId: intent.accountId,
      isPrimary: false,
    );
    return AccountDatabaseReady(
      lease: IsarAccountDatabaseLease(
        accountId: intent.accountId,
        lease: lease,
      ),
      initializedNow: true,
    );
  }

  @override
  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  ) {
    throw UnimplementedError();
  }
}
