import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/search_routes.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/article_scope.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/ui/home/article_list/article_list.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

class _FixedArticleListController extends ArticleListController {
  static List<Article> items = <Article>[];

  @override
  Future<ArticleListState> build() async {
    return ArticleListState(
      items: items,
      hasMore: false,
      nextOffset: items.length,
    );
  }
}

Feed _buildFeed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed'
    ..siteUrl = 'https://example.com';
}

Article _buildArticle({
  int id = 42,
  bool isRead = false,
  bool isStarred = false,
  bool isReadLater = false,
}) {
  return Article()
    ..id = id
    ..feedId = 10
    ..link = 'https://example.com/article/$id'
    ..title = 'Context Article $id'
    ..contentHtml = '<p>Hello world</p>'
    ..publishedAt = DateTime.utc(2026, 1, 2)
    ..updatedAt = DateTime.utc(2026, 1, 2)
    ..isRead = isRead
    ..isStarred = isStarred
    ..isReadLater = isReadLater;
}

Future<GoRouter> _pumpArticleList(
  WidgetTester tester, {
  required Article article,
  RecordingArticleActionService? actionService,
  int? selectedArticleId,
  String initialLocation = '/all',
  ArticleScope initialScope = ArticleScope.all,
  String Function(Article article)? articleLocationBuilder,
  Size? surfaceSize,
}) async {
  debugFleurTargetPlatformOverride = TargetPlatform.macOS;
  addTearDown(() => debugFleurTargetPlatformOverride = null);
  if (surfaceSize != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surfaceSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  _FixedArticleListController.items = [article];
  addTearDown(() => _FixedArticleListController.items = <Article>[]);

  Widget list({
    required int? selectedArticleId,
    String? baseLocation,
    String? articleRoutePrefix,
  }) {
    return AppMenuHost(
      child: Scaffold(
        body: ArticleList(
          selectedArticleId: selectedArticleId,
          baseLocation: baseLocation,
          articleRoutePrefix: articleRoutePrefix,
          articleLocationBuilder: articleLocationBuilder,
        ),
      ),
    );
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/all',
        builder: (context, state) => list(selectedArticleId: selectedArticleId),
      ),
      GoRoute(
        path: '/all/article/:id',
        builder: (context, state) =>
            Scaffold(body: Text('all:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/feed/:id',
        builder: (context, state) => list(selectedArticleId: selectedArticleId),
      ),
      GoRoute(
        path: '/feed/:feedId/article/:id',
        builder: (context, state) =>
            Scaffold(body: Text('feed:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/starred',
        builder: (context, state) => list(selectedArticleId: selectedArticleId),
      ),
      GoRoute(
        path: '/starred/article/:id',
        builder: (context, state) =>
            Scaffold(body: Text('starred:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => list(
          selectedArticleId: selectedArticleId,
          baseLocation: '/search',
          articleRoutePrefix: '/search',
        ),
      ),
      GoRoute(
        path: '/search/article/:id',
        builder: (context, state) {
          final query = state.uri.query;
          final id = state.pathParameters['id'];
          return Scaffold(
            body: Text(query.isEmpty ? 'search:$id' : 'search:$id?$query'),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('article-list-${initialLocation}_$initialScope'),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        articleListControllerProvider.overrideWith(
          _FixedArticleListController.new,
        ),
        articleListFilterProvider.overrideWith(
          (ref) => ArticleListFilter(scope: initialScope),
        ),
        articleProvider(
          article.id,
        ).overrideWith((ref) => Stream.value(article)),
        feedsProvider.overrideWith((ref) => Stream.value([_buildFeed()])),
        articleActionServiceProvider.overrideWithValue(
          actionService ?? RecordingArticleActionService(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _openContextMenu(WidgetTester tester, Article article) async {
  await tester.tapAt(
    tester.getCenter(find.text(article.title!)),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('article context menu shows core actions without navigating', (
    tester,
  ) async {
    final article = _buildArticle();
    final router = await _pumpArticleList(tester, article: article);

    await _openContextMenu(tester, article);

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
    expect(find.text('Open article'), findsOneWidget);
    expect(find.text('Mark read'), findsOneWidget);
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Read Later'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Open in browser'), findsOneWidget);
    expect(find.text('Mark unread'), findsNothing);
    expect(find.text('Unstar'), findsNothing);
    expect(find.text('Remove from Read Later'), findsNothing);
  });

  testWidgets('article context menu labels reflect article state', (
    tester,
  ) async {
    final article = _buildArticle(
      isRead: true,
      isStarred: true,
      isReadLater: true,
    );
    await _pumpArticleList(tester, article: article);

    await _openContextMenu(tester, article);

    expect(find.text('Mark unread'), findsOneWidget);
    expect(find.text('Unstar'), findsOneWidget);
    expect(find.text('Remove from Read Later'), findsOneWidget);
    expect(find.text('Mark read'), findsNothing);
    expect(find.text('Star'), findsNothing);
    expect(find.text('Read Later'), findsNothing);
  });

  testWidgets('article context menu actions call article action service', (
    tester,
  ) async {
    final article = _buildArticle();
    final actions = RecordingArticleActionService();
    await _pumpArticleList(tester, article: article, actionService: actions);

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(actions.markReadCalls, [(articleId: article.id, isRead: true)]);

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();
    expect(actions.toggleStarCalls, [article.id]);

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Read Later'));
    await tester.pumpAndSettle();
    expect(actions.toggleReadLaterCalls, [article.id]);
  });

  testWidgets('copy link writes clipboard and shows feedback', (tester) async {
    final article = _buildArticle();
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    await _pumpArticleList(tester, article: article);

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(clipboardText, article.link);
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('tap article replaces route when reader can be embedded', (
    tester,
  ) async {
    final article = _buildArticle();
    final router = await _pumpArticleList(
      tester,
      article: article,
      surfaceSize: const Size(1200, 800),
    );

    await tester.tap(find.text(article.title!));
    await tester.pumpAndSettle();

    expect(find.text('all:${article.id}'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('tap article pushes secondary route when too narrow', (
    tester,
  ) async {
    final article = _buildArticle();
    final router = await _pumpArticleList(
      tester,
      article: article,
      surfaceSize: const Size(800, 600),
    );

    await tester.tap(find.text(article.title!));
    await tester.pumpAndSettle();

    expect(find.text('all:${article.id}'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('open article context action navigates to default route', (
    tester,
  ) async {
    final article = _buildArticle();
    final router = await _pumpArticleList(tester, article: article);

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Open article'));
    await tester.pumpAndSettle();

    expect(find.text('all:${article.id}'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('open article context action respects scoped routes', (
    tester,
  ) async {
    for (final scenario in [
      (
        start: '/feed/10',
        scope: const ArticleScope.feed(10),
        expected: 'feed:42',
      ),
      (start: '/starred', scope: ArticleScope.starred, expected: 'starred:42'),
      (start: '/search', scope: ArticleScope.all, expected: 'search:42'),
    ]) {
      final article = _buildArticle();
      final router = await _pumpArticleList(
        tester,
        article: article,
        initialLocation: scenario.start,
        initialScope: scenario.scope,
      );

      await _openContextMenu(tester, article);
      await tester.tap(find.text('Open article'));
      await tester.pumpAndSettle();

      expect(find.text(scenario.expected), findsOneWidget);
      expect(router.canPop(), isTrue);
    }
  });

  testWidgets('open article context action can preserve search query routes', (
    tester,
  ) async {
    final article = _buildArticle();
    const routeState = SearchRouteState(
      query: 'claude',
      scope: ArticleScope.starred,
    );
    final router = await _pumpArticleList(
      tester,
      article: article,
      initialLocation: searchLocation(routeState),
      initialScope: ArticleScope.starred,
      articleLocationBuilder: (article) =>
          searchArticleLocation(routeState, article.id),
    );

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Open article'));
    await tester.pumpAndSettle();

    expect(find.text('search:42?q=claude&scope=starred'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('open article context action does not close selected article', (
    tester,
  ) async {
    final article = _buildArticle();
    final router = await _pumpArticleList(
      tester,
      article: article,
      selectedArticleId: article.id,
    );

    await _openContextMenu(tester, article);
    await tester.tap(find.text('Open article'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
  });
}
