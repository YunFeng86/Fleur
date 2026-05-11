import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../logging/app_logger.dart';
import '../../utils/path_manager.dart';
import 'account.dart';

class AccountsState {
  AccountsState({
    required this.version,
    required this.activeAccountId,
    required this.accounts,
  });

  final int version;
  final String activeAccountId;
  final List<Account> accounts;

  static AccountsState fromJson(Map<String, Object?> json) {
    final rawAccounts = json['accounts'];
    final accounts = <Account>[];
    if (rawAccounts is List) {
      for (final raw in rawAccounts) {
        if (raw is! Map) continue;
        try {
          accounts.add(Account.fromJson(raw.cast<String, Object?>()));
        } catch (_) {
          // Skip corrupt entries so one bad account does not invalidate the
          // rest of the account file.
        }
      }
    }
    final version = json['version'];
    final activeAccountId = json['activeAccountId'];
    return AccountsState(
      version: version is int ? version : 1,
      activeAccountId: activeAccountId is String ? activeAccountId : '',
      accounts: accounts,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'activeAccountId': activeAccountId,
      'accounts': accounts.map((a) => a.toJson()).toList(growable: false),
    };
  }

  Account? findById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }
}

class AccountStore {
  static const int currentVersion = 1;

  Future<AccountsState> loadOrCreate() async {
    final f = await _file();
    try {
      if (await f.exists()) {
        final raw = await f.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final state = AccountsState.fromJson(decoded.cast<String, Object?>());
          final fixed = _fixup(state);
          if (fixed != null) {
            await save(fixed);
            return fixed;
          }
          return state;
        }
        AppLogger.w(
          'Account file ignored: unexpected JSON shape',
          tag: 'settings',
          context: const <String, Object?>{
            'file': 'accounts',
            'store': 'AccountStore',
          },
        );
      }
    } catch (e, s) {
      AppLogger.w(
        'Account load failed; creating default account',
        tag: 'settings',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{
          'file': 'accounts',
          'store': 'AccountStore',
        },
      );
      // fall through: best-effort create a fresh state.
    }

    final now = DateTime.now();
    final primary = Account(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );
    final state = AccountsState(
      version: currentVersion,
      activeAccountId: primary.id,
      accounts: [primary],
    );
    await save(state);
    return state;
  }

  Future<void> save(AccountsState state) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(state.toJson()));
  }

  Future<File> _file() async {
    final dir = await PathManager.getStateDir();
    return File('${dir.path}${Platform.pathSeparator}accounts.json');
  }

  AccountsState? _fixup(AccountsState state) {
    // Ensure there is at least one account and an active account.
    if (state.accounts.isEmpty) {
      final now = DateTime.now();
      final primary = Account(
        id: 'local',
        type: AccountType.local,
        name: 'Local',
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
      );
      return AccountsState(
        version: currentVersion,
        activeAccountId: primary.id,
        accounts: [primary],
      );
    }
    final active = state.findById(state.activeAccountId);
    if (active == null) {
      return AccountsState(
        version: state.version,
        activeAccountId: state.accounts.first.id,
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
