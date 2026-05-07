import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/backend_content_capabilities.dart';
import 'account_providers.dart';

final backendContentCapabilitiesProvider = Provider<BackendContentCapabilities>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    return BackendContentCapabilities.forAccountType(account.type);
  },
);
