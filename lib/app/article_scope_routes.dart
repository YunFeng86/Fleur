import 'package:go_router/go_router.dart';

import '../models/article_scope.dart';

String scopeLocation(ArticleScope scope) {
  return switch (scope.type) {
    ArticleScopeType.all => '/all',
    ArticleScopeType.starred => '/starred',
    ArticleScopeType.readLater => '/read-later',
    ArticleScopeType.feed => '/feed/${scope.id}',
    ArticleScopeType.category => '/category/${scope.id}',
    ArticleScopeType.tag => '/tag/${scope.id}',
  };
}

String scopedArticleLocation(ArticleScope scope, int articleId) {
  return '${scopeLocation(scope)}/article/$articleId';
}

ArticleScope scopeFromRoute(GoRouterState state) {
  final segments = state.uri.pathSegments;
  return scopeFromPathSegments(segments) ?? ArticleScope.all;
}

ArticleScope? scopeFromPathSegments(List<String> segments) {
  if (segments.isEmpty) return ArticleScope.all;
  return switch (segments.first) {
    'all' => ArticleScope.all,
    'starred' => ArticleScope.starred,
    'read-later' => ArticleScope.readLater,
    'feed' =>
      _idAt(segments, 1) == null
          ? null
          : ArticleScope.feed(_idAt(segments, 1)!),
    'category' =>
      _idAt(segments, 1) == null
          ? null
          : ArticleScope.category(_idAt(segments, 1)!),
    'tag' =>
      _idAt(segments, 1) == null ? null : ArticleScope.tag(_idAt(segments, 1)!),
    _ => null,
  };
}

int? scopedArticleIdFromRoute(GoRouterState state) {
  return scopedArticleIdFromPathSegments(state.uri.pathSegments);
}

int? scopedArticleIdFromPathSegments(List<String> segments) {
  final articleIndex = segments.indexOf('article');
  if (articleIndex < 0 || articleIndex + 1 >= segments.length) return null;
  return int.tryParse(segments[articleIndex + 1]);
}

int? _idAt(List<String> segments, int index) {
  if (index >= segments.length) return null;
  return int.tryParse(segments[index]);
}
