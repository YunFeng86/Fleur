import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/router.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/article_scope.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/navigation_history_provider.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/features/reader/reader.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/home/reading_workspace_screen.dart';
import 'package:fleur/utils/platform.dart';

import 'test_utils/critical_workflow_test_support.dart';

class _EmptyArticleListController extends ArticleListController {
  @override
  Future<ArticleListState> build() async {
    return const ArticleListState(items: [], hasMore: false, nextOffset: 0);
  }
}

class _NoopNavigationHistoryController extends NavigationHistoryController {
  @override
  void bindRouter(GoRouter _) {}
}

Article _buildArticle() {
  return Article()
    ..id = 42
    ..feedId = 10
    ..link = 'https://example.com/articles/42'
    ..title = 'Saved route article'
    ..contentHtml = ''
    ..publishedAt = DateTime.utc(2026, 1, 2)
    ..updatedAt = DateTime.utc(2026, 1, 2);
}

Feed _buildFeed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed'
    ..siteUrl = 'https://example.com';
}

void main() {
  testWidgets(
    'saved workspace routes synchronize scope and selected article id',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final article = _buildArticle();
      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
          navigationHistoryControllerProvider.overrideWith(
            _NoopNavigationHistoryController.new,
          ),
          articleListFilterProvider.overrideWith(
            (ref) => const ArticleListFilter(
              unreadOnly: true,
              searchQuery: 'stale query',
              searchInContentOverride: true,
            ),
          ),
          articleProvider(
            article.id,
          ).overrideWith((ref) => Stream.value(article)),
          readerProgressStoreProvider.overrideWithValue(
            InMemoryReaderProgressStore(),
          ),
          imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
          articleActionServiceProvider.overrideWithValue(
            RecordingArticleActionService(),
          ),
          feedsProvider.overrideWith((ref) => Stream.value([_buildFeed()])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const routes = <({String location, ArticleScope scope, int? articleId})>[
        (location: '/starred', scope: ArticleScope.starred, articleId: null),
        (
          location: '/read-later',
          scope: ArticleScope.readLater,
          articleId: null,
        ),
        (
          location: '/starred/article/42',
          scope: ArticleScope.starred,
          articleId: 42,
        ),
        (
          location: '/read-later/article/42',
          scope: ArticleScope.readLater,
          articleId: 42,
        ),
      ];

      for (final route in routes) {
        router.go(route.location);
        await tester.pump();

        final screen = tester.widget<ReadingWorkspaceScreen>(
          find.byType(ReadingWorkspaceScreen),
        );
        expect(screen.scope, route.scope);
        expect(screen.selectedArticleId, route.articleId);

        await tester.pump();
        final filter = container.read(articleListFilterProvider);
        expect(filter.scope, route.scope);
        expect(filter.unreadOnly, isFalse);
        expect(filter.searchQuery, isEmpty);
        expect(filter.searchInContentOverride, isNull);
        expect(tester.takeException(), isNull);
      }

      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
