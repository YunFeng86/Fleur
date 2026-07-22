import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../services/sync/backend_capabilities.dart';

final backendCapabilitiesProvider = Provider<BackendCapabilities>((ref) {
  final account = ref.watch(activeAccountProvider);
  return BackendCapabilities.forAccount(account);
});
