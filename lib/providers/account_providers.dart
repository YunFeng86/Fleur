import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/accounts/account.dart';
import '../services/accounts/account_cleanup_service.dart';
import '../services/accounts/account_store.dart';
import '../services/accounts/credential_store.dart';

final accountStoreProvider = Provider<AccountStore>((ref) => AccountStore());

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

class AccountsController extends AsyncNotifier<AccountsState> {
  @override
  Future<AccountsState> build() async {
    return ref.read(accountStoreProvider).loadOrCreate();
  }

  Future<void> setActive(String accountId) async {
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
    state = AsyncValue.data(next);
    await ref.read(accountStoreProvider).save(next);
  }

  Future<String> addAccount({
    required AccountType type,
    required String name,
    String? baseUrl,
    String? profileId,
    String? dbName,
  }) async {
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
      createdAt: now,
      updatedAt: now,
    );
    final next = AccountsState(
      version: cur.version,
      activeAccountId: cur.activeAccountId,
      accounts: [...cur.accounts, account],
    );
    state = AsyncValue.data(next);
    await ref.read(accountStoreProvider).save(next);
    return id;
  }

  Future<void> renameAccount(String accountId, String name) async {
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
    state = AsyncValue.data(next);
    await ref.read(accountStoreProvider).save(next);
  }

  Future<void> updateAccountConnection({
    required String accountId,
    String? baseUrl,
    String? profileId,
  }) async {
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
    state = AsyncValue.data(next);
    await ref.read(accountStoreProvider).save(next);
  }

  Future<void> deleteAccount(String accountId) async {
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
    state = AsyncValue.data(next);
    await ref.read(accountStoreProvider).save(next);

    // Best-effort cleanup: credentials/state/db for the deleted account.
    unawaited(
      AccountCleanupService(
        credentials: ref.read(credentialStoreProvider),
      ).deleteAccountData(target).catchError((_) {}),
    );
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
