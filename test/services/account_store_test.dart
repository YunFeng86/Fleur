import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/accounts/account_store.dart';

void main() {
  test('AccountsState.fromJson skips malformed account entries', () {
    final now = DateTime.utc(2026, 1, 1).toIso8601String();

    final state = AccountsState.fromJson(<String, Object?>{
      'version': AccountStore.currentVersion,
      'activeAccountId': 'valid-account',
      'accounts': <Object?>[
        <String, Object?>{
          'id': 'valid-account',
          'type': 'local',
          'name': 'Valid',
          'isPrimary': true,
          'createdAt': now,
          'updatedAt': now,
        },
        <String, Object?>{
          'id': 'broken-account',
          'type': 'unknown',
          'name': 'Broken',
          'createdAt': now,
          'updatedAt': now,
        },
      ],
    });

    expect(state.accounts, hasLength(1));
    expect(state.accounts.single.id, 'valid-account');
    expect(state.activeAccountId, 'valid-account');
  });
}
