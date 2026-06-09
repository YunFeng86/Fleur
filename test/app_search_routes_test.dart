import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/app/search_routes.dart';
import 'package:fleur/models/article_scope.dart';

void main() {
  group('Search route codec', () {
    test('decodes empty search to default state', () {
      final state = searchStateFromUri(Uri.parse('/search'));

      expect(state.query, '');
      expect(state.scope, ArticleScope.all);
      expect(state.unreadOnly, isFalse);
      expect(state.searchInContent, isTrue);
      expect(searchLocation(state), '/search');
    });

    test('encodes canonical query parameters and omits defaults', () {
      expect(
        searchLocation(const SearchRouteState(query: 'claude')),
        '/search?q=claude',
      );
      expect(
        searchLocation(
          const SearchRouteState(
            query: 'claude code',
            scope: ArticleScope.starred,
            unreadOnly: true,
            searchInContent: false,
          ),
        ),
        '/search?q=claude+code&scope=starred&unread=1&content=0',
      );
    });

    test('round trips supported search scopes', () {
      const states = <SearchRouteState>[
        SearchRouteState(query: 'q', scope: ArticleScope.all),
        SearchRouteState(query: 'q', scope: ArticleScope.starred),
        SearchRouteState(query: 'q', scope: ArticleScope.readLater),
        SearchRouteState(query: 'q', scope: ArticleScope.feed(12)),
        SearchRouteState(query: 'q', scope: ArticleScope.category(34)),
      ];

      for (final state in states) {
        final decoded = searchStateFromUri(Uri.parse(searchLocation(state)));
        expect(decoded, state);
      }
    });

    test(
      'decodes search article routes and keeps query when encoding article',
      () {
        final state = searchStateFromUri(
          Uri.parse('/search/article/42?q=claude&scope=feed:12&content=0'),
        );

        expect(state.query, 'claude');
        expect(state.scope, const ArticleScope.feed(12));
        expect(state.searchInContent, isFalse);
        expect(
          searchArticleLocation(state, 42),
          '/search/article/42?q=claude&scope=feed:12&content=0',
        );
      },
    );

    test('falls back to all for invalid search scope ids', () {
      for (final uri in [
        Uri.parse('/search?q=q&scope=feed:x'),
        Uri.parse('/search?q=q&scope=category:x'),
        Uri.parse('/search?q=q&scope=tag:1'),
      ]) {
        expect(searchStateFromUri(uri).scope, ArticleScope.all);
      }
    });

    test('canonicalizes blank query to /search and clears filters', () {
      final state = searchStateFromUri(
        Uri.parse('/search?q=%20&scope=starred&unread=1&content=0'),
      );

      expect(state, const SearchRouteState());
      expect(searchLocation(state), '/search');
      expect(searchArticleLocation(state, 42), '/search');
    });
  });
}
