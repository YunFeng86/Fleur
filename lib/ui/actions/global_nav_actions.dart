import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/nav_destination.dart';
import '../../providers/query_providers.dart';

void handleGlobalNavSelection(
  BuildContext context,
  WidgetRef ref,
  GlobalNavDestination dest,
) {
  switch (dest) {
    case GlobalNavDestination.feeds:
      // Leaving other top-level sections should bring you back to the normal
      // feed browsing state.
      ref
          .read(articleListFilterProvider.notifier)
          .update((filter) => filter.enterFeedsSection());
      context.go(destinationLocation(dest));
      return;
    case GlobalNavDestination.saved:
    case GlobalNavDestination.search:
    case GlobalNavDestination.settings:
      context.go(destinationLocation(dest));
      return;
  }
}
