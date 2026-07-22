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
    if (rawAccounts is! List) {
      throw const FormatException('Account JSON accounts is not a list');
    }
    final accounts = <Account>[];
    for (final raw in rawAccounts) {
      if (raw is! Map) {
        throw const FormatException('Account JSON entry is not an object');
      }
      accounts.add(Account.fromJson(raw.cast<String, Object?>()));
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
