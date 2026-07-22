import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/subscriptions/subscriptions.dart';
import 'package:fleur/models/article_scope.dart';
import 'package:fleur/providers/query_providers.dart';

void main() {
  test('selectFeed clears browse filters by default', () {
    final container = ProviderContainer(
      overrides: [
        articleListFilterProvider.overrideWith(
          (ref) => const ArticleListFilter(
            scope: ArticleScope.category(3),
            unreadOnly: true,
            searchQuery: 'stale search',
            searchInContentOverride: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    SubscriptionFeedBrowsing.selectFeed(container.read, 42);

    final filter = container.read(articleListFilterProvider);
    expect(filter.scope, const ArticleScope.feed(42));
    expect(filter.unreadOnly, isTrue);
    expect(filter.searchQuery, isEmpty);
    expect(filter.searchInContentOverride, isNull);
  });

  test('selectFeed can preserve existing browse filters', () {
    final container = ProviderContainer(
      overrides: [
        articleListFilterProvider.overrideWith(
          (ref) => const ArticleListFilter(
            unreadOnly: true,
            searchQuery: 'keep this',
            searchInContentOverride: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    SubscriptionFeedBrowsing.selectFeed(
      container.read,
      42,
      resetFilters: false,
    );

    final filter = container.read(articleListFilterProvider);
    expect(filter.scope, const ArticleScope.feed(42));
    expect(filter.unreadOnly, isTrue);
    expect(filter.searchQuery, 'keep this');
    expect(filter.searchInContentOverride, isTrue);
  });
}
