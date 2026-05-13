import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/app/article_scope_routes.dart';
import 'package:fleur/models/article_scope.dart';

void main() {
  group('ArticleScope route codec', () {
    test('encodes scope locations', () {
      expect(scopeLocation(ArticleScope.all), '/all');
      expect(scopeLocation(ArticleScope.starred), '/starred');
      expect(scopeLocation(ArticleScope.readLater), '/read-later');
      expect(scopeLocation(const ArticleScope.feed(12)), '/feed/12');
      expect(scopeLocation(const ArticleScope.category(34)), '/category/34');
      expect(scopeLocation(const ArticleScope.tag(56)), '/tag/56');
    });

    test('encodes scoped article locations', () {
      expect(
        scopedArticleLocation(const ArticleScope.feed(12), 42),
        '/feed/12/article/42',
      );
      expect(
        scopedArticleLocation(ArticleScope.starred, 42),
        '/starred/article/42',
      );
      expect(scopedArticleLocation(ArticleScope.all, 42), '/all/article/42');
    });

    test('decodes path segments into scopes', () {
      expect(scopeFromPathSegments(const []), ArticleScope.all);
      expect(scopeFromPathSegments(const ['all']), ArticleScope.all);
      expect(scopeFromPathSegments(const ['starred']), ArticleScope.starred);
      expect(
        scopeFromPathSegments(const ['read-later']),
        ArticleScope.readLater,
      );
      expect(
        scopeFromPathSegments(const ['feed', '12']),
        const ArticleScope.feed(12),
      );
      expect(
        scopeFromPathSegments(const ['category', '34']),
        const ArticleScope.category(34),
      );
      expect(
        scopeFromPathSegments(const ['tag', '56']),
        const ArticleScope.tag(56),
      );
    });

    test('decodes scope and article id from scoped article paths', () {
      const paths = <({ArticleScope scope, String path})>[
        (scope: ArticleScope.all, path: '/all/article/42'),
        (scope: ArticleScope.starred, path: '/starred/article/42'),
        (scope: ArticleScope.readLater, path: '/read-later/article/42'),
        (scope: ArticleScope.feed(12), path: '/feed/12/article/42'),
        (scope: ArticleScope.category(34), path: '/category/34/article/42'),
        (scope: ArticleScope.tag(56), path: '/tag/56/article/42'),
      ];

      for (final entry in paths) {
        final segments = Uri.parse(entry.path).pathSegments;
        expect(scopeFromPathSegments(segments), entry.scope);
        expect(scopedArticleIdFromPathSegments(segments), 42);
      }
    });

    test('returns null for invalid scoped route fragments', () {
      expect(scopeFromPathSegments(const ['feed']), isNull);
      expect(scopeFromPathSegments(const ['feed', 'abc']), isNull);
      expect(scopeFromPathSegments(const ['search']), isNull);
      expect(
        scopedArticleIdFromPathSegments(const ['feed', '12', 'article', 'x']),
        isNull,
      );
    });
  });
}
