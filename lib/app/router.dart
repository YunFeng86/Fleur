import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../models/nav_destination.dart';
import '../screens/home_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/platform.dart';
import '../ui/app_shell.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/motion.dart';

const _homeSectionKey = ValueKey<String>('home-section');
const _savedSectionKey = ValueKey<String>('saved-section');
const _searchSectionKey = ValueKey<String>('search-section');

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

  return GoRouter(
    errorPageBuilder: (context, state) {
      return const NoTransitionPage(child: _NotFoundScreen());
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentUri: state.uri, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _homeSectionKey,
                child: const HomeScreen(selectedArticleId: null),
              );
            },
          ),
          GoRoute(
            path: '/article/:id',
            name: 'article',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }

              final spec = LayoutSpec.fromContext(context);

              if (isDesktop) {
                if (spec.desktopEmbedsReader) {
                  return sectionPage(
                    state: state,
                    pageKey: _homeSectionKey,
                    child: HomeScreen(selectedArticleId: id),
                  );
                }
                // Medium-small / small desktop: reader is a secondary page.
                return MaterialPage(child: ReaderScreen(articleId: id));
              }

              // Non-desktop: only embed the reader when it can keep a minimum
              // comfortable measure; otherwise use a dedicated reader page.
              if (spec.canEmbedReader(listWidth: kHomeListWidth)) {
                return sectionPage(
                  state: state,
                  pageKey: _homeSectionKey,
                  child: HomeScreen(selectedArticleId: id),
                );
              }

              // Narrow/mobile: dedicated reader screen with default Material
              // route transition.
              return MaterialPage(child: ReaderScreen(articleId: id));
            },
          ),
          GoRoute(
            path: '/saved',
            name: 'saved',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _savedSectionKey,
                child: const SavedScreen(selectedArticleId: null),
              );
            },
          ),
          GoRoute(
            path: '/saved/article/:id',
            name: 'savedArticle',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }

              final spec = LayoutSpec.fromContext(context);

              if (isDesktop) {
                if (spec.desktopEmbedsReader) {
                  return sectionPage(
                    state: state,
                    pageKey: _savedSectionKey,
                    child: SavedScreen(selectedArticleId: id),
                  );
                }
                return MaterialPage(
                  child: ReaderScreen(
                    articleId: id,
                    fallbackBackLocation: '/saved',
                  ),
                );
              }

              if (spec.canEmbedReader(listWidth: kDesktopListWidth)) {
                return sectionPage(
                  state: state,
                  pageKey: _savedSectionKey,
                  child: SavedScreen(selectedArticleId: id),
                );
              }

              return MaterialPage(
                child: ReaderScreen(
                  articleId: id,
                  fallbackBackLocation: '/saved',
                ),
              );
            },
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) {
              return sectionPage(
                state: state,
                pageKey: _searchSectionKey,
                child: const SearchScreen(selectedArticleId: null),
              );
            },
          ),
          GoRoute(
            path: '/search/article/:id',
            name: 'searchArticle',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const NoTransitionPage(child: _NotFoundScreen());
              }

              final spec = LayoutSpec.fromContext(context);

              if (isDesktop) {
                if (spec.desktopEmbedsReader) {
                  return sectionPage(
                    state: state,
                    pageKey: _searchSectionKey,
                    child: SearchScreen(selectedArticleId: id),
                  );
                }
                return MaterialPage(
                  child: ReaderScreen(
                    articleId: id,
                    fallbackBackLocation: '/search',
                  ),
                );
              }

              if (spec.canEmbedReader(listWidth: kDesktopListWidth)) {
                return sectionPage(
                  state: state,
                  pageKey: _searchSectionKey,
                  child: SearchScreen(selectedArticleId: id),
                );
              }

              return MaterialPage(
                child: ReaderScreen(
                  articleId: id,
                  fallbackBackLocation: '/search',
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
              return sectionPage(
                state: state,
                child: SettingsScreen(initialTab: tab),
              );
            },
          ),
        ],
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
