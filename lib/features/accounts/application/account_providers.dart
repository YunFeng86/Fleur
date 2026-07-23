import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_cleanup_service.dart';
import '../data/account_store.dart';
import '../data/credential_store.dart';
import '../domain/account.dart';
import '../domain/accounts_state.dart';

final accountStoreProvider = Provider<AccountStore>((ref) => AccountStore());

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

class AccountsController extends AsyncNotifier<AccountsState> {
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<AccountsState> build() async {
    return ref.read(accountStoreProvider).loadOrCreate();
  }

  Future<void> setActive(String accountId) {
    return _serializeMutation<void>(() async {
      final cur = state.valueOrNull;
      if (cur == null) return;
      if (cur.activeAccountId == accountId) return;
      final exists = cur.findById(accountId) != null;
      if (!exists) return;
      final next = AccountsState(
        version: cur.version,
        activeAccountId: accountId,
        accounts: cur.accounts,
      );
      await _persistAndPublish(next);
    });
  }

  Future<String> addAccount({
    required AccountType type,
    required String name,
    String? baseUrl,
    String? profileId,
    String? dbName,
  }) {
    return _serializeMutation<String>(() async {
      final cur = state.valueOrNull ?? await future;
      final now = DateTime.now();
      final id = AccountStore.newAccountId();
      final account = Account(
        id: id,
        type: type,
        name: name.trim().isEmpty ? type.wire : name.trim(),
        baseUrl: baseUrl?.trim(),
        profileId: profileId?.trim(),
        dbName: dbName,
        databaseInitialized: false,
        createdAt: now,
        updatedAt: now,
      );
      final next = AccountsState(
        version: cur.version,
        activeAccountId: cur.activeAccountId,
        accounts: [...cur.accounts, account],
      );
      await _persistAndPublish(next);
      return id;
    });
  }

  Future<void> markDatabaseInitialized(String accountId) {
    return _serializeMutation<void>(() async {
      final cur = state.valueOrNull ?? await future;
      final idx = cur.accounts.indexWhere((account) => account.id == accountId);
      if (idx < 0 || cur.accounts[idx].databaseInitialized) return;

      final nextAccounts = [...cur.accounts];
      nextAccounts[idx] = nextAccounts[idx].copyWith(
        databaseInitialized: true,
        updatedAt: DateTime.now(),
      );
      await _persistAndPublish(
        AccountsState(
          version: cur.version,
          activeAccountId: cur.activeAccountId,
          accounts: nextAccounts,
        ),
      );
    });
  }

  Future<void> renameAccount(String accountId, String name) {
    return _serializeMutation<void>(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;

      final cur = state.valueOrNull ?? await future;
      final idx = cur.accounts.indexWhere((a) => a.id == accountId);
      if (idx < 0) return;

      final now = DateTime.now();
      final nextAccounts = [...cur.accounts];
      nextAccounts[idx] = nextAccounts[idx].copyWith(
        name: trimmed,
        updatedAt: now,
      );
      final next = AccountsState(
        version: cur.version,
        activeAccountId: cur.activeAccountId,
        accounts: nextAccounts,
      );
      await _persistAndPublish(next);
    });
  }

  Future<void> updateAccountConnection({
    required String accountId,
    String? baseUrl,
    String? profileId,
  }) {
    return _serializeMutation<void>(() async {
      final cur = state.valueOrNull ?? await future;
      final idx = cur.accounts.indexWhere((a) => a.id == accountId);
      if (idx < 0) return;

      final current = cur.accounts[idx];
      final trimmedBaseUrl = baseUrl?.trim();
      final trimmedProfileId = profileId?.trim();
      final now = DateTime.now();
      final nextAccounts = [...cur.accounts];
      nextAccounts[idx] = current.copyWith(
        baseUrl: trimmedBaseUrl == null || trimmedBaseUrl.isEmpty
            ? current.baseUrl
            : trimmedBaseUrl,
        profileId: trimmedProfileId == null || trimmedProfileId.isEmpty
            ? current.profileId
            : trimmedProfileId,
        updatedAt: now,
      );
      final next = AccountsState(
        version: cur.version,
        activeAccountId: cur.activeAccountId,
        accounts: nextAccounts,
      );
      await _persistAndPublish(next);
    });
  }

  Future<void> deleteAccount(String accountId) {
    return _serializeMutation<void>(() async {
      final cur = state.valueOrNull ?? await future;
      final target = cur.findById(accountId);
      if (target == null) return;
      if (target.isPrimary) return;

      final remaining = cur.accounts.where((a) => a.id != accountId).toList();
      if (remaining.isEmpty) return;

      var nextActiveId = cur.activeAccountId;
      if (nextActiveId == accountId) {
        nextActiveId = remaining.first.id;
      }

      final next = AccountsState(
        version: cur.version,
        activeAccountId: nextActiveId,
        accounts: remaining,
      );
      await _persistAndPublish(next);

      // Complete best-effort cleanup before reporting account deletion done.
      await AccountCleanupService(
        credentials: ref.read(credentialStoreProvider),
      ).deleteAccountData(target).catchError((_) {});
    });
  }

  Future<void> _persistAndPublish(AccountsState next) async {
    await ref.read(accountStoreProvider).save(next);
    state = AsyncValue.data(next);
  }

  Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await mutation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final accountsControllerProvider =
    AsyncNotifierProvider<AccountsController, AccountsState>(
      AccountsController.new,
    );

final activeAccountProvider = Provider<Account>((ref) {
  final state = ref.watch(accountsControllerProvider).valueOrNull;
  if (state == null) {
    // This provider should only be used after accounts are loaded.
    return Account(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  final active = state.findById(state.activeAccountId);
  return active ?? state.accounts.first;
});
