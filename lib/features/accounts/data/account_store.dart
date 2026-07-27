import 'dart:io';
import 'dart:math';

import '../../../services/logging/app_logger.dart';
import '../../../services/persistence/durable_json_store.dart';
import '../../../utils/path_manager.dart';
import '../domain/account.dart';
import '../domain/accounts_state.dart';

class AccountStore {
  AccountStore({DurableFileSystem fileSystem = const IoDurableFileSystem()})
    : _fileSystem = fileSystem;

  static const int currentVersion = 1;

  final DurableFileSystem _fileSystem;

  Future<AccountsState> loadOrCreate() async {
    final store = await _store();
    return store.runExclusive(() => _loadOrCreateLocked(store));
  }

  Future<AccountsState> _loadOrCreateLocked(
    DurableJsonStore<AccountsState> store,
  ) async {
    try {
      final snapshot = await store.read();
      if (snapshot != null) {
        if (snapshot.wasRecovered) {
          AppLogger.w(
            'Account file recovered',
            tag: 'settings',
            context: <String, Object?>{
              'file': 'accounts',
              'store': 'AccountStore',
              'source': snapshot.source.name,
            },
          );
        }

        final fixed = _fixup(snapshot.value);
        if (fixed != null) {
          await store.write(fixed);
          return fixed;
        }
        return snapshot.value;
      }
    } catch (e, s) {
      AppLogger.w(
        'Account load failed',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'accounts',
          'store': 'AccountStore',
        },
      );
      rethrow;
    }

    final state = _createDefaultState();
    await store.write(state);
    return state;
  }

  Future<void> save(AccountsState state) async {
    final store = await _store();
    try {
      await store.write(state);
    } catch (e, s) {
      AppLogger.w(
        'Account save failed',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'accounts',
          'store': 'AccountStore',
        },
      );
      rethrow;
    }
  }

  Future<DurableJsonStore<AccountsState>> _store() async {
    final file = await _file();
    return DurableJsonStore<AccountsState>(
      file: file,
      decode: _decode,
      encode: (state) => state.toJson(),
      fileSystem: _fileSystem,
    );
  }

  AccountsState _decode(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('Account JSON root is not an object');
    }
    final json = decoded.cast<String, Object?>();
    final rawAccounts = json['accounts'];
    if (rawAccounts is! List || rawAccounts.isEmpty) {
      throw const FormatException('Account JSON has no account entries');
    }

    final state = AccountsState.fromJson(json);
    if (state.accounts.isEmpty) {
      throw const FormatException('Account JSON has no valid accounts');
    }
    final databaseOwners = <String, String>{};
    for (final account in state.accounts.where(
      (account) => !account.isPrimary,
    )) {
      final name = account.isolatedDatabaseName;
      final key = Account.databaseNameCollisionKey(name);
      final existingOwner = databaseOwners[key];
      if (existingOwner != null && existingOwner != account.id) {
        throw FormatException(
          'Accounts $existingOwner and ${account.id} share database $name',
        );
      }
      databaseOwners[key] = account.id;
    }
    return state;
  }

  AccountsState _createDefaultState() {
    final now = DateTime.now();
    final primary = Account(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
      databaseInitialized: false,
      createdAt: now,
      updatedAt: now,
    );
    return AccountsState(
      version: currentVersion,
      activeAccountId: primary.id,
      accounts: [primary],
    );
  }

  Future<File> _file() async {
    final dir = await PathManager.getStateDir();
    return File('${dir.path}${Platform.pathSeparator}accounts.json');
  }

  AccountsState? _fixup(AccountsState state) {
    // Decoding already enforces a non-empty account list. Only repair the
    // active pointer here so defaults are created exclusively for a new file.
    final active = state.findById(state.activeAccountId);
    if (active == null || active.deletionPending) {
      final fallback = state.accounts
          .where((account) => !account.deletionPending)
          .firstOrNull;
      if (fallback == null) return null;
      return AccountsState(
        version: state.version,
        activeAccountId: fallback.id,
        accounts: state.accounts,
      );
    }
    return null;
  }

  static String newAccountId() {
    // Short, URL-safe-ish id for DB name + file keys.
    // 16 chars base32-ish: good enough uniqueness for local use.
    const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buf.write(alphabet[rnd.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }
}
