import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/article_scope.dart';
import '../../../providers/query_providers.dart';

/// The small read contract needed by subscription application actions.
///
/// Keeping the provider lookup at the boundary lets callers use either a
/// [WidgetRef] or a [ProviderContainer] without making this action depend on
/// a widget or a particular shell.
typedef SubscriptionProviderRead =
    T Function<T>(ProviderListenable<T> provider);

/// Applies the browsing policy used after a subscription is selected.
///
/// A normal selection clears stale search/content filters. Callers that are
/// already managing those filters can opt out and only change the scope.
abstract final class SubscriptionFeedBrowsing {
  static void selectFeed(
    SubscriptionProviderRead read,
    int feedId, {
    bool resetFilters = true,
  }) {
    final controller = read(articleListFilterProvider.notifier);
    if (resetFilters) {
      controller.update((filter) => filter.selectFeed(feedId));
      return;
    }

    controller.update(
      (filter) => filter.copyWith(scope: ArticleScope.feed(feedId)),
    );
  }
}
