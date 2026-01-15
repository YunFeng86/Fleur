import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';
import '../screens/reader_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(selectedArticleId: null),
      ),
      GoRoute(
        path: '/article/:id',
        name: 'article',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _NotFoundScreen();
          }

          final width = MediaQuery.sizeOf(context).width;
          // Desktop/tablet: keep the 3-pane layout and just select the article.
          if (width >= 900) {
            return HomeScreen(selectedArticleId: id);
          }

          // Mobile: push to a dedicated reader screen.
          return ReaderScreen(articleId: id);
        },
      ),
    ],
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Not found')),
    );
  }
}

