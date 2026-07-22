import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../services/sync/backend_capabilities.dart';
import '../services/sync/outbox/outbox_store.dart';
import 'backend_capabilities_provider.dart';
import 'service_providers.dart';

final outboxChangesProvider = StreamProvider.autoDispose<String>((ref) {
  return OutboxStore.changes;
});

final outboxPendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Re-compute when outbox changes anywhere.
  ref.watch(outboxChangesProvider);

  final account = ref.watch(activeAccountProvider);
  final capabilities = ref.watch(backendCapabilitiesProvider);
  if (!capabilities.isVisible(BackendFeature.outboxFlush)) {
    return 0;
  }

  final outbox = ref.watch(outboxStoreProvider);
  final pending = await outbox.load(account.id);
  return pending.length;
});

/// Consecutive "no progress" / "failed flush" count in the foreground outbox flusher.
///
/// Used for UI indication and for coarse background scheduling backoff.
final outboxFlushStallCountProvider = StateProvider<int>((ref) => 0);
