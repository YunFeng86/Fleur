import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/router.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/app_shell.dart';
import 'package:fleur/utils/platform.dart';

import '../test_utils/critical_workflow_test_support.dart';

GoRouter _buildShellRouter() {
  return GoRouter(
    initialLocation: '/all',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentUri: state.uri, child: child),
        routes: [
          GoRoute(
            path: '/all',
            builder: (context, state) => const Text('all page'),
          ),
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
      ),
    ],
  );
}

Widget _buildHarness(GoRouter router) {
  return ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      activeAccountProvider.overrideWithValue(buildTestAccount()),
      feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
      categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
      tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
      allUnreadCountsProvider.overrideWith(
        (ref) => Stream.value(<int?, int>{}),
      ),
      outboxPendingCountProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Finder _shellIconButton(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(IconButton),
  );
}

IconButton _iconButton(WidgetTester tester, Key key) {
  return tester.widget<IconButton>(_shellIconButton(key));
}

Color? _resolvedForegroundColor(
  WidgetTester tester,
  Key key,
  Set<WidgetState> states,
) {
  return _iconButton(tester, key).style?.foregroundColor?.resolve(states);
}

Future<void> _pumpDesktopShell(WidgetTester tester, GoRouter router) async {
  debugFleurTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(() => debugFleurTargetPlatformOverride = null);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(_buildHarness(router));
  await tester.pumpAndSettle();
}

Future<void> _sendAltArrow(
  WidgetTester tester,
  LogicalKeyboardKey arrowKey,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(arrowKey);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _sendMetaBracket(
  WidgetTester tester,
  LogicalKeyboardKey bracketKey,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(bracketKey);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shell buttons replay route history for embedded article routes',
    (tester) async {
      final router = _buildShellRouter();
      addTearDown(router.dispose);
      await _pumpDesktopShell(tester, router);

      expect(
        _iconButton(tester, const Key('shell_forward_button')).onPressed,
        isNull,
      );

      router.go('/feed/10');
      await tester.pumpAndSettle();
      router.go('/feed/10/article/42');
      await tester.pumpAndSettle();

      expect(router.canPop(), isFalse);
      expect(
        _iconButton(tester, const Key('shell_back_button')).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('shell_back_button')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/feed/10',
      );
      expect(
        _iconButton(tester, const Key('shell_forward_button')).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('shell_forward_button')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/feed/10/article/42',
      );
    },
  );

  testWidgets('expanded controls use a visibly muted disabled foreground', (
    tester,
  ) async {
    final router = _buildShellRouter();
    addTearDown(router.dispose);
    await _pumpDesktopShell(tester, router);

    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);

    final context = tester.element(
      _shellIconButton(const Key('shell_forward_button')),
    );
    final scheme = Theme.of(context).colorScheme;

    expect(
      _resolvedForegroundColor(tester, const Key('shell_forward_button'), {
        WidgetState.disabled,
      }),
      scheme.onSurface.withValues(alpha: 0.28),
    );
    expect(
      _resolvedForegroundColor(
        tester,
        const Key('shell_sidebar_button'),
        <WidgetState>{},
      ),
      scheme.onSurfaceVariant,
    );
  });

  testWidgets('collapsed capsule controls use the same history state', (
    tester,
  ) async {
    final router = _buildShellRouter();
    addTearDown(router.dispose);
    await _pumpDesktopShell(tester, router);

    router.go('/feed/10');
    await tester.pumpAndSettle();
    router.go('/feed/10/article/42');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(
      _iconButton(tester, const Key('shell_back_button')).onPressed,
      isNotNull,
    );
    expect(
      _iconButton(tester, const Key('shell_forward_button')).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);
    expect(
      _iconButton(tester, const Key('shell_back_button')).onPressed,
      isNotNull,
    );
    expect(
      _iconButton(tester, const Key('shell_forward_button')).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('shell_back_button')));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10',
    );
    expect(
      _iconButton(tester, const Key('shell_forward_button')).onPressed,
      isNotNull,
    );
  });

  testWidgets('Alt+ArrowLeft and Alt+ArrowRight navigate shell history', (
    tester,
  ) async {
    final router = _buildShellRouter();
    addTearDown(router.dispose);
    await _pumpDesktopShell(tester, router);

    await _sendAltArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');

    router.go('/feed/10');
    await tester.pumpAndSettle();
    router.go('/feed/10/article/42');
    await tester.pumpAndSettle();

    await _sendAltArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10/article/42',
    );

    await _sendAltArrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10',
    );

    await _sendAltArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10/article/42',
    );
  });

  testWidgets('command bracket shortcuts are ignored outside macOS', (
    tester,
  ) async {
    final router = _buildShellRouter();
    addTearDown(router.dispose);
    await _pumpDesktopShell(tester, router);

    router.go('/feed/10');
    await tester.pumpAndSettle();
    router.go('/feed/10/article/42');
    await tester.pumpAndSettle();

    await _sendMetaBracket(tester, LogicalKeyboardKey.bracketLeft);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10/article/42',
    );
  });

  testWidgets('macOS command bracket shortcuts navigate shell history', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = _buildShellRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_buildHarness(router));
    await tester.pumpAndSettle();

    router.go('/feed/10');
    await tester.pumpAndSettle();
    router.go('/feed/10/article/42');
    await tester.pumpAndSettle();

    await _sendMetaBracket(tester, LogicalKeyboardKey.bracketLeft);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10',
    );

    await _sendMetaBracket(tester, LogicalKeyboardKey.bracketRight);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/feed/10/article/42',
    );
  });
}
