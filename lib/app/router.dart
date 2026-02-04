import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/platform.dart';
import '../ui/app_shell.dart';
import '../ui/global_nav.dart';
import '../ui/layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
              return const NoTransitionPage(
                child: HomeScreen(selectedArticleId: null),
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

              final totalWidth = MediaQuery.sizeOf(context).width;
              final width = effectiveContentWidth(totalWidth);

              if (isDesktop) {
                final mode = desktopModeForWidth(width);
                if (desktopReaderEmbedded(mode)) {
                  return NoTransitionPage(
                    child: HomeScreen(selectedArticleId: id),
                  );
                }
                // Medium-small / small desktop: reader is a secondary page.
                return MaterialPage(child: ReaderScreen(articleId: id));
              }

              // Width >= 600: use multi-column HomeScreen with selected article,
              // but keep the transition instant to avoid visual "page jumps".
              if (width >= 600) {
                return NoTransitionPage(
                  child: HomeScreen(selectedArticleId: id),
                );
              }

              // Narrow/mobile: dedicated reader screen with default Material
              // route transition.
              return MaterialPage(child: ReaderScreen(articleId: id));
            },
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: DashboardScreen());
            },
          ),
          GoRoute(
            path: '/saved',
            name: 'saved',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: SavedScreen(selectedArticleId: null),
              );
            },
            routes: [
              GoRoute(
                path: 'article/:id',
                name: 'savedArticle',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(child: _NotFoundScreen());
                  }

                  final totalWidth = MediaQuery.sizeOf(context).width;
                  final width = effectiveContentWidth(totalWidth);

                  if (isDesktop) {
                    final mode = desktopModeForWidth(width);
                    if (desktopReaderEmbedded(mode)) {
                      return NoTransitionPage(
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

                  if (width >= 600) {
                    return NoTransitionPage(
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
            ],
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: SearchScreen(selectedArticleId: null),
              );
            },
            routes: [
              GoRoute(
                path: 'article/:id',
                name: 'searchArticle',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const NoTransitionPage(child: _NotFoundScreen());
                  }

                  final totalWidth = MediaQuery.sizeOf(context).width;
                  final width = effectiveContentWidth(totalWidth);

                  if (isDesktop) {
                    final mode = desktopModeForWidth(width);
                    if (desktopReaderEmbedded(mode)) {
                      return NoTransitionPage(
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

                  if (width >= 600) {
                    return NoTransitionPage(
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
            ],
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: SettingsScreen());
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
