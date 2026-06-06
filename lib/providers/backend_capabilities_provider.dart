import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/backend_capabilities.dart';
import 'account_providers.dart';

final backendCapabilitiesProvider = Provider<BackendCapabilities>((ref) {
  final account = ref.watch(activeAccountProvider);
  return BackendCapabilities.forAccount(account);
});
