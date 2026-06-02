import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleur/app/account_gate.dart';
import 'package:fleur/db/isar_db.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';

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
      openTarget: (target) {
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
        child: MaterialApp(home: AccountGate(dbSessionManager: manager)),
      ),
    );
    await tester.pump();

    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    tester.view.physicalSize = const Size(1300, 900);
    await tester.pump();

    expect(openCalls, 1);
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
    SharedPreferences.setMockInitialValues(<String, Object>{
      'integrity:last_run:${firstIsar.name}':
          DateTime.now().millisecondsSinceEpoch,
      'integrity:last_run:${secondIsar.name}':
          DateTime.now().millisecondsSinceEpoch,
    });
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
      openTarget: (target) async {
        return openCompleters[target.accountId]!.future;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountStoreProvider.overrideWithValue(store)],
        child: MaterialApp(home: AccountGate(dbSessionManager: manager)),
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

    expect(firstIsar.closeCalls, 1);
    expect(firstIsar.isOpen, false);
    expect(secondIsar.closeCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
    expect(secondIsar.closeCalls, 1);
  });
}
