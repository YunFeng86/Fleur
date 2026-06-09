import '../models/article_scope.dart';

class SearchRouteState {
  const SearchRouteState({
    this.query = '',
    this.scope = ArticleScope.all,
    this.unreadOnly = false,
    this.searchInContent = true,
  });

  final String query;
  final ArticleScope scope;
  final bool unreadOnly;
  final bool searchInContent;

  bool get hasQuery => query.trim().isNotEmpty;

  SearchRouteState copyWith({
    String? query,
    ArticleScope? scope,
    bool? unreadOnly,
    bool? searchInContent,
  }) {
    return SearchRouteState(
      query: query ?? this.query,
      scope: scope ?? this.scope,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      searchInContent: searchInContent ?? this.searchInContent,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchRouteState &&
        other.query == query &&
        other.scope == scope &&
        other.unreadOnly == unreadOnly &&
        other.searchInContent == searchInContent;
  }

  @override
  int get hashCode => Object.hash(query, scope, unreadOnly, searchInContent);
}

SearchRouteState searchStateFromUri(Uri uri) {
  final query = uri.queryParameters['q']?.trim() ?? '';
  if (query.isEmpty) return const SearchRouteState();

  return SearchRouteState(
    query: query,
    scope: _scopeFromQuery(uri.queryParameters['scope']) ?? ArticleScope.all,
    unreadOnly: uri.queryParameters['unread'] == '1',
    searchInContent: uri.queryParameters['content'] != '0',
  );
}

String searchLocation(SearchRouteState state) {
  final query = state.query.trim();
  if (query.isEmpty) return '/search';

  return _location(
    path: '/search',
    state: state.copyWith(query: query),
  );
}

String searchArticleLocation(SearchRouteState state, int articleId) {
  final query = state.query.trim();
  if (query.isEmpty) return '/search';

  return _location(
    path: '/search/article/$articleId',
    state: state.copyWith(query: query),
  );
}

String _location({required String path, required SearchRouteState state}) {
  final parts = <String>[
    'q=${Uri.encodeQueryComponent(state.query)}',
    if (state.scope != ArticleScope.all) 'scope=${_scopeQuery(state.scope)}',
    if (state.unreadOnly) 'unread=1',
    if (!state.searchInContent) 'content=0',
  ];
  if (parts.isEmpty) return path;
  return '$path?${parts.join('&')}';
}

String _scopeQuery(ArticleScope scope) {
  return switch (scope.type) {
    ArticleScopeType.all => 'all',
    ArticleScopeType.starred => 'starred',
    ArticleScopeType.readLater => 'read-later',
    ArticleScopeType.feed => 'feed:${scope.id}',
    ArticleScopeType.category => 'category:${scope.id}',
    ArticleScopeType.tag => 'all',
  };
}

ArticleScope? _scopeFromQuery(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return switch (raw) {
    'all' => ArticleScope.all,
    'starred' => ArticleScope.starred,
    'read-later' => ArticleScope.readLater,
    _ when raw.startsWith('feed:') => _scopeWithId(
      raw.substring('feed:'.length),
      ArticleScope.feed,
    ),
    _ when raw.startsWith('category:') => _scopeWithId(
      raw.substring('category:'.length),
      ArticleScope.category,
    ),
    _ => null,
  };
}

ArticleScope? _scopeWithId(String raw, ArticleScope Function(int id) factory) {
  final id = int.tryParse(raw);
  if (id == null) return null;
  return factory(id);
}
