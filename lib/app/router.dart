import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'article_scope_routes.dart';
import 'search_routes.dart';
import 'settings_routes.dart';
import '../models/article_scope.dart';
import '../providers/navigation_history_provider.dart';
import '../screens/add_subscription_screen.dart';
import '../screens/reading_workspace_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/adaptive_workspace_layout.dart';
import '../ui/app_shell.dart';
import '../ui/motion.dart';

const _workspaceSectionKey = ValueKey<String>('workspace-section');
const _searchSectionKey = ValueKey<String>('search-section');
const _addSubscriptionSectionKey = ValueKey<String>('add-subscription-section');

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root-navigator',
);
final _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell-navigator',
);

final routerProvider = Provider<GoRouter>((ref) {
  Page<void> sectionPage({
    required GoRouterState state,
    required Widget child,
    LocalKey? pageKey,
  }) {
    return CustomTransitionPage<void>(
      key: pageKey ?? state.pageKey,
      transitionDuration: AppMotion.pageTransitionDuration,
      reverseTransitionDuration: AppMotion.pageReverseTransitionDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AppMotion.sectionTransition(
          context: context,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }

  Page<void> secondaryPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      opaque: true,
      transitionDuration: AppMotion.pageTransitionDuration,
      reverseTransitionDuration: AppMotion.pageReverseTransitionDuration,
      child: _ReaderPageSurface(child: child),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.emphasizedDecelerate,
          reverseCurve: AppMotion.emphasizedAccelerate,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Page<void> workspaceArticlePage(GoRouterState state) {
    final scope = scopeFromRoute(state);
    final id = scopedArticleIdFromRoute(state);
    if (id == null) return const NoTransitionPage(child: _NotFoundScreen());

    final child = ReadingWorkspaceScreen(scope: scope, selectedArticleId: id);
    if (state.extra == WorkspaceReaderPresentation.secondaryPage) {
      return secondaryPage(state: state, child: child);
    }
    return sectionPage(
      state: state,
      pageKey: _workspaceSectionKey,
      child: child,
    );
  }

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    errorPageBuilder: (context, state) {
      return const NoTransitionPage(child: _NotFoundScreen());
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(currentUri: state.uri, child: child);
        },
        routes: [
          GoRoute(path: '/', redirect: (context, state) => '/all'),
          GoRoute(
            path: '/all',
            name: 'all',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: const ReadingWorkspaceScreen(
                  scope: ArticleScope.all,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/all/article/:articleId',
            name: 'allArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/starred',
            name: 'starred',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: const ReadingWorkspaceScreen(
                  scope: ArticleScope.starred,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/starred/article/:articleId',
            name: 'starredArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/read-later',
            name: 'readLater',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: const ReadingWorkspaceScreen(
                  scope: ArticleScope.readLater,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/read-later/article/:articleId',
            name: 'readLaterArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/feed/:feedId',
            name: 'feed',
            pageBuilder: (context, state) {
              final scope = scopeFromRoute(state);
              if (scope.type != ArticleScopeType.feed) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: ReadingWorkspaceScreen(
                  scope: scope,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/feed/:feedId/article/:articleId',
            name: 'feedArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/category/:categoryId',
            name: 'category',
            pageBuilder: (context, state) {
              final scope = scopeFromRoute(state);
              if (scope.type != ArticleScopeType.category) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: ReadingWorkspaceScreen(
                  scope: scope,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/category/:categoryId/article/:articleId',
            name: 'categoryArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/tag/:tagId',
            name: 'tag',
            pageBuilder: (context, state) {
              final scope = scopeFromRoute(state);
              if (scope.type != ArticleScopeType.tag) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }
              return sectionPage(
                state: state,
                pageKey: _workspaceSectionKey,
                child: ReadingWorkspaceScreen(
                  scope: scope,
                  selectedArticleId: null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/tag/:tagId/article/:articleId',
            name: 'tagArticle',
            pageBuilder: (context, state) {
              return workspaceArticlePage(state);
            },
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            redirect: (context, state) {
              final routeState = searchStateFromUri(state.uri);
              if (!routeState.hasQuery && state.uri.query.isNotEmpty) {
                return '/search';
              }
              return null;
            },
            pageBuilder: (context, state) {
              final routeState = searchStateFromUri(state.uri);
              return sectionPage(
                state: state,
                pageKey: _searchSectionKey,
                child: SearchScreen(
                  selectedArticleId: null,
                  routeState: routeState,
                ),
              );
            },
          ),
          GoRoute(
            path: '/search/article/:id',
            name: 'searchArticle',
            redirect: (context, state) {
              final routeState = searchStateFromUri(state.uri);
              if (!routeState.hasQuery) return '/search';
              return null;
            },
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }

              final routeState = searchStateFromUri(state.uri);
              final child = SearchScreen(
                selectedArticleId: id,
                routeState: routeState,
              );
              if (state.extra == WorkspaceReaderPresentation.secondaryPage) {
                return secondaryPage(state: state, child: child);
              }
              return sectionPage(
                state: state,
                pageKey: _searchSectionKey,
                child: child,
              );
            },
          ),
          GoRoute(
            path: '/add-subscription',
            name: 'addSubscription',
            pageBuilder: (context, state) {
              final initialCategoryId = int.tryParse(
                state.uri.queryParameters['categoryId'] ?? '',
              );
              return sectionPage(
                state: state,
                pageKey: _addSubscriptionSectionKey,
                child: AddSubscriptionScreen(
                  initialCategoryId: initialCategoryId,
                ),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) {
              final tab = settingsTabFromQueryValue(
                state.uri.queryParameters['tab'],
              );
              final settingId = state.uri.queryParameters['setting'];
              return sectionPage(
                state: state,
                child: SettingsScreen(
                  initialTab: tab,
                  initialSettingId: settingId,
                  showBack: true,
                  fallbackBackLocation: '/all',
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
  ref.read(navigationHistoryControllerProvider.notifier).bindRouter(router);
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(body: Center(child: Text(l10n.notFound)));
  }
}

class _ReaderPageSurface extends StatelessWidget {
  const _ReaderPageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).fleurSurface.reader,
      child: child,
    );
  }
}
