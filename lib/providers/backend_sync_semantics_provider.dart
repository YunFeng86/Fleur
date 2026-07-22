import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../services/sync/backend_sync_semantics.dart';

final backendSyncSemanticsProvider = Provider<BackendSyncSemantics>((ref) {
  final account = ref.watch(activeAccountProvider);
  return BackendSyncSemantics.forAccount(account);
});
