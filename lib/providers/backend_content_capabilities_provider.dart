import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../services/sync/backend_content_capabilities.dart';

final backendContentCapabilitiesProvider = Provider<BackendContentCapabilities>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    return BackendContentCapabilities.forAccount(account);
  },
);
