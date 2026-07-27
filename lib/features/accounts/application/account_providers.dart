import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_safety/data_safety.dart';
import '../data/account_cleanup_service.dart';
import '../data/account_store.dart';
import '../data/credential_store.dart';
import '../domain/account.dart';
import '../domain/accounts_state.dart';

final accountStoreProvider = Provider<AccountStore>((ref) => AccountStore());

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

final accountCleanupProvider = Provider<AccountCleanupService>(
  (ref) => AccountCleanupService(
    credentials: ref.read(credentialStoreProvider),
    databaseLifecycle: createAccountDatabaseLifecycle(
      findAccount: (accountId) async {
        final state = await ref.read(accountStoreProvider).loadOrCreate();
        return state.findById(accountId);
      },
    ),
  ),
);

class AccountsController extends AsyncNotifier<AccountsState> {
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<AccountsState> build() async {
    final store = ref.read(accountStoreProvider);
    final loaded = await store.loadOrCreate();
    var recovered = loaded;
    var changed = false;

    for (final account in loaded.accounts) {
      if (!account.deletionPending || account.isPrimary) continue;
      try {
        await ref.read(accountCleanupProvider).deleteAccountData(account);
        recovered = _withoutAccount(recovered, account.id);
        changed = true;
      } catch (_) {
        // Keep the persisted marker. A later startup can safely retry.
      }
    }

    if (!changed) return recovered;
    try {
      await store.save(recovered);
      return recovered;
    } catch (_) {
      // Cleanup is idempotent. Keep the durable pending state visible so the
      // next startup retries instead of failing the whole application boot.
      return loaded;
    }
  }

  Future<void> setActive(String accountId) {
    return _serializeMutation<void>(() async {
      final cur = state.valueOrNull;
      if (cur == null) return;
      if (cur.activeAccountId == accountId) return;
      final target = cur.findById(accountId);
      if (target == null || target.deletionPending) return;
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
      final conflictingOwner = cur.accounts
          .where((existing) => !existing.isPrimary)
          .where(
            (existing) =>
                existing.isolatedDatabaseName == account.isolatedDatabaseName,
          )
          .firstOrNull;
      if (conflictingOwner != null) {
        throw StateError(
          'Database ${account.isolatedDatabaseName} is already owned by '
          '${conflictingOwner.id}.',
        );
      }
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
      if (idx < 0 ||
          cur.accounts[idx].databaseInitialized ||
          cur.accounts[idx].deletionPending) {
        return;
      }

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
      if (idx < 0 || cur.accounts[idx].deletionPending) return;

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
      if (idx < 0 || cur.accounts[idx].deletionPending) return;

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

      final remaining = cur.accounts
          .where((account) => account.id != accountId)
          .toList();
      final activeCandidates = remaining
          .where((account) => !account.deletionPending)
          .toList();
      if (activeCandidates.isEmpty) return;

      var nextActiveId = cur.activeAccountId;
      final active = cur.findById(nextActiveId);
      if (nextActiveId == accountId ||
          active == null ||
          active.deletionPending) {
        nextActiveId = activeCandidates.first.id;
      }

      final wasAlreadyPending = target.deletionPending;
      var pending = cur;
      if (!wasAlreadyPending || nextActiveId != cur.activeAccountId) {
        final pendingAccounts = [...cur.accounts];
        final targetIndex = pendingAccounts.indexWhere(
          (account) => account.id == accountId,
        );
        pendingAccounts[targetIndex] = target.copyWith(
          deletionPending: true,
          updatedAt: wasAlreadyPending ? target.updatedAt : DateTime.now(),
        );
        pending = AccountsState(
          version: cur.version,
          activeAccountId: nextActiveId,
          accounts: pendingAccounts,
        );
        await _persistAndPublish(pending);
      }

      try {
        await ref
            .read(accountCleanupProvider)
            .deleteAccountData(pending.findById(accountId)!);
      } catch (error, stackTrace) {
        if (!wasAlreadyPending) {
          await _persistAndPublish(cur);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      final next = AccountsState(
        version: cur.version,
        activeAccountId: nextActiveId,
        accounts: remaining,
      );
      await _persistAndPublish(next);
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

  AccountsState _withoutAccount(AccountsState current, String accountId) {
    final accounts = current.accounts
        .where((account) => account.id != accountId)
        .toList();
    if (accounts.isEmpty) return current;
    final active = current.findById(current.activeAccountId);
    final nextActiveId =
        active == null || active.id == accountId || active.deletionPending
        ? accounts.firstWhere((account) => !account.deletionPending).id
        : active.id;
    return AccountsState(
      version: current.version,
      activeAccountId: nextActiveId,
      accounts: accounts,
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
  if (active != null && !active.deletionPending) return active;
  return state.accounts.firstWhere((account) => !account.deletionPending);
});
