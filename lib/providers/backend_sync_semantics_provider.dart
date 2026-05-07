import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/backend_sync_semantics.dart';
import 'account_providers.dart';

final backendSyncSemanticsProvider = Provider<BackendSyncSemantics>((ref) {
  final account = ref.watch(activeAccountProvider);
  return BackendSyncSemantics.forAccountType(account.type);
});
