import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/providers/navigation_history_provider.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/all',
    routes: [
      GoRoute(path: '/all', builder: (context, state) => const Text('all')),
      GoRoute(
        path: '/feed/:feedId',
        builder: (context, state) =>
            Text('feed:${state.pathParameters['feedId']}'),
      ),
      GoRoute(
        path: '/feed/:feedId/article/:articleId',
        builder: (context, state) =>
            Text('article:${state.pathParameters['articleId']}'),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => Text('search:${state.uri.query}'),
      ),
    ],
  );
}

Future<ProviderContainer> _pumpHistoryHarness(
  WidgetTester tester,
  GoRouter router,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  container
      .read(navigationHistoryControllerProvider.notifier)
      .bindRouter(router);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('records routes, dedupes, and replays back/forward', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);

    expect(container.read(navigationHistoryControllerProvider).entries, [
      '/all',
    ]);

    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );
    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();

    expect(container.read(navigationHistoryControllerProvider).entries, [
      '/all',
      '/feed/10',
      '/feed/10/article/42',
    ]);

    controller.goBack();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10',
    );
    expect(
      container.read(navigationHistoryControllerProvider).canGoForward,
      isTrue,
    );

    controller.goForward();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10/article/42',
    );
  });

  testWidgets(
    'reconciles adjacent external route changes as back and forward',
    (tester) async {
      final router = _buildRouter();
      addTearDown(router.dispose);
      final container = await _pumpHistoryHarness(tester, router);

      router.go('/feed/10');
      await tester.pumpAndSettle();
      router.go('/feed/10/article/42');
      await tester.pumpAndSettle();
      router.go('/feed/10');
      await tester.pumpAndSettle();

      final state = container.read(navigationHistoryControllerProvider);
      expect(state.entries, ['/all', '/feed/10', '/feed/10/article/42']);
      expect(state.index, 1);
      expect(state.canGoForward, isTrue);

      router.go('/feed/10/article/42');
      await tester.pumpAndSettle();

      final nextState = container.read(navigationHistoryControllerProvider);
      expect(nextState.entries, ['/all', '/feed/10', '/feed/10/article/42']);
      expect(nextState.index, 2);
    },
  );

  testWidgets('ordinary visits to an earlier URI truncate the forward tail', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);
    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );

    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();
    controller.visit('/feed/10');
    await tester.pumpAndSettle();

    final state = container.read(navigationHistoryControllerProvider);
    expect(state.entries, [
      '/all',
      '/feed/10',
      '/feed/10/article/42',
      '/feed/10',
    ]);
    expect(state.index, 3);
    expect(state.canGoForward, isFalse);
  });

  testWidgets('records rapid visits issued before a frame settles', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);
    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );

    controller.visit('/feed/10');
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();

    final state = container.read(navigationHistoryControllerProvider);
    expect(state.entries, ['/all', '/feed/10', '/feed/10/article/42']);
    expect(state.index, 2);
    expect(state.canGoForward, isFalse);
  });

  testWidgets('replays every rapid back command before a frame settles', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);
    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );

    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();

    controller.goBack();
    controller.goBack();
    await tester.pumpAndSettle();

    final state = container.read(navigationHistoryControllerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
    expect(state.index, 0);
    expect(state.canGoBack, isFalse);
    expect(state.canGoForward, isTrue);
  });

  testWidgets('replaces the current entry for debounced search updates', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);
    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );

    controller.visit('/search');
    await tester.pumpAndSettle();
    controller.replaceCurrent('/search?q=f');
    await tester.pumpAndSettle();
    controller.replaceCurrent('/search?q=flutter');
    await tester.pumpAndSettle();

    expect(container.read(navigationHistoryControllerProvider).entries, [
      '/all',
      '/search?q=flutter',
    ]);

    controller.goBack();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');

    controller.goForward();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/search?q=flutter',
    );
  });

  testWidgets('ordinary navigation after back truncates the forward tail', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);

    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );
    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();
    controller.goBack();
    await tester.pumpAndSettle();

    controller.visit('/search?q=flutter');
    await tester.pumpAndSettle();

    expect(container.read(navigationHistoryControllerProvider).entries, [
      '/all',
      '/feed/10',
      '/search?q=flutter',
    ]);
    expect(
      container.read(navigationHistoryControllerProvider).canGoForward,
      isFalse,
    );
  });

  testWidgets('visit during replay cannot leave a stale replay marker', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    final container = await _pumpHistoryHarness(tester, router);
    final controller = container.read(
      navigationHistoryControllerProvider.notifier,
    );

    controller.visit('/feed/10');
    await tester.pumpAndSettle();
    controller.visit('/feed/10/article/42');
    await tester.pumpAndSettle();

    controller.goBack();
    controller.visit('/search?q=flutter');
    await tester.pumpAndSettle();
    controller.visit('/feed/10');
    await tester.pumpAndSettle();

    final state = container.read(navigationHistoryControllerProvider);
    expect(state.entries, [
      '/all',
      '/feed/10',
      '/search?q=flutter',
      '/feed/10',
    ]);
    expect(state.index, 3);
    expect(state.canGoForward, isFalse);
  });
}
