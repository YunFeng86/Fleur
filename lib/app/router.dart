import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'article_scope_routes.dart';
import 'search_routes.dart';
import 'settings_routes.dart';
import '../models/article_scope.dart';
import '../providers/core_providers.dart';
import '../screens/add_subscription_screen.dart';
import '../screens/reading_workspace_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../ui/app_menu.dart';
import '../ui/app_shell.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/motion.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';

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
  LayoutSpec routeLayoutSpec(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final sidebarLayoutMode = sidebarLayoutModeForWidth(size.width);
    final sidebarPresentationMode =
        sidebarLayoutMode == SidebarLayoutMode.inline
        ? ref.read(sidebarPresentationModeProvider)
        : SidebarPresentationMode.collapsed;
    return LayoutSpec.fromTotalSize(
      totalWidth: size.width,
      totalHeight: size.height,
      sidebarPresentationMode: sidebarPresentationMode,
    );
  }

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
      opaque: false,
      transitionDuration: AppMotion.pageTransitionDuration,
      reverseTransitionDuration: AppMotion.pageReverseTransitionDuration,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.emphasizedDecelerate,
          reverseCurve: AppMotion.emphasizedAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Page<void> settingsLayerPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      opaque: false,
      transitionDuration: AppMotion.pageTransitionDuration,
      reverseTransitionDuration: AppMotion.pageReverseTransitionDuration,
      child: AppMenuHost(
        child: Builder(
          builder: (context) {
            final surfaces = Theme.of(context).fleurSurface;
            return ColoredBox(
              color: Colors.transparent,
              child: WorkspaceLayerSurface(color: surfaces.list, child: child),
            );
          },
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppMotion.reduceMotion(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.emphasizedDecelerate,
          reverseCurve: AppMotion.emphasizedAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Page<void> workspaceArticlePage(BuildContext context, GoRouterState state) {
    final scope = scopeFromRoute(state);
    final id = scopedArticleIdFromRoute(state);
    if (id == null) return const NoTransitionPage(child: _NotFoundScreen());

    final spec = routeLayoutSpec(context);
    final embedsReader = isDesktop
        ? spec.desktopEmbedsReader
        : spec.canEmbedReader(listWidth: kHomeListWidth);

    if (embedsReader) {
      return sectionPage(
        state: state,
        pageKey: _workspaceSectionKey,
        child: ReadingWorkspaceScreen(scope: scope, selectedArticleId: id),
      );
    }

    return secondaryPage(
      state: state,
      child: ReaderScreen(
        articleId: id,
        fallbackBackLocation: scopeLocation(scope),
      ),
    );
  }

  return GoRouter(
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
              return workspaceArticlePage(context, state);
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
              return workspaceArticlePage(context, state);
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
              return workspaceArticlePage(context, state);
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
              return workspaceArticlePage(context, state);
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
              return workspaceArticlePage(context, state);
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
              return workspaceArticlePage(context, state);
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
              final fallbackBackLocation = searchLocation(routeState);
              final spec = routeLayoutSpec(context);

              if (isDesktop) {
                if (spec.desktopEmbedsReader) {
                  return sectionPage(
                    state: state,
                    pageKey: _searchSectionKey,
                    child: SearchScreen(
                      selectedArticleId: id,
                      routeState: routeState,
                    ),
                  );
                }
                return secondaryPage(
                  state: state,
                  child: ReaderScreen(
                    articleId: id,
                    fallbackBackLocation: fallbackBackLocation,
                  ),
                );
              }

              if (spec.canEmbedReader(listWidth: kDesktopListWidth)) {
                return sectionPage(
                  state: state,
                  pageKey: _searchSectionKey,
                  child: SearchScreen(
                    selectedArticleId: id,
                    routeState: routeState,
                  ),
                );
              }

              return secondaryPage(
                state: state,
                child: ReaderScreen(
                  articleId: id,
                  fallbackBackLocation: fallbackBackLocation,
                ),
              );
            },
          ),
          GoRoute(
            path: '/add-subscription',
            name: 'addSubscription',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _addSubscriptionSectionKey,
                child: const AddSubscriptionScreen(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final tab = settingsTabFromQueryValue(
            state.uri.queryParameters['tab'],
          );
          return settingsLayerPage(
            state: state,
            child: SettingsScreen(
              initialTab: tab,
              showBack: true,
              fallbackBackLocation: '/all',
            ),
          );
        },
      ),
    ],
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(body: Center(child: Text(l10n.notFound)));
  }
}
