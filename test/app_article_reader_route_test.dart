import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/router.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/reader_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/features/reader/reader.dart';

import 'test_utils/critical_workflow_test_support.dart';

class _SingleArticleListController extends ArticleListController {
  static late Article article;

  @override
  Future<ArticleListState> build() async {
    return ArticleListState(items: [article], hasMore: false, nextOffset: 1);
  }
}

Feed _buildFeed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed'
    ..siteUrl = 'https://example.com';
}

Article _buildArticle() {
  return Article()
    ..id = 42
    ..feedId = 10
    ..link = 'https://example.com/article/42'
    ..title = 'Narrow Route Article'
    ..contentHtml = ''
    ..publishedAt = DateTime.utc(2026, 1, 2)
    ..updatedAt = DateTime.utc(2026, 1, 2);
}

void main() {
  testWidgets(
    'narrow article route opens and closes without page key crashes',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final article = _buildArticle();
      _SingleArticleListController.article = article;

      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            articleListControllerProvider.overrideWith(
              _SingleArticleListController.new,
            ),
            articleListFilterProvider.overrideWith(
              (ref) => const ArticleListFilter(),
            ),
            articleProvider(
              article.id,
            ).overrideWith((ref) => Stream.value(article)),
            readerSettingsStoreProvider.overrideWithValue(
              FakeReaderSettingsStore(const ReaderSettings()),
            ),
            readerProgressStoreProvider.overrideWithValue(
              InMemoryReaderProgressStore(),
            ),
            imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
            articleActionServiceProvider.overrideWithValue(
              RecordingArticleActionService(),
            ),
            feedsProvider.overrideWith((ref) => Stream.value([_buildFeed()])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0}),
            ),
            outboxPendingCountProvider.overrideWith((ref) async => 0),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: AppTheme.light(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      addTearDown(() => router.dispose());
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
      expect(tester.takeException(), isNull);
      expect(find.text(article.title!), findsOneWidget);

      final opened = router.push<void>(
        '/all/article/42',
        extra: WorkspaceReaderPresentation.secondaryPage,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final readerLeftDuringTransition = tester
          .getTopLeft(find.byType(ReaderView))
          .dx;
      expect(readerLeftDuringTransition, greaterThan(0));
      expect(readerLeftDuringTransition, lessThan(640));

      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      expect(find.byType(ReaderView), findsOneWidget);
      expect(
        tester.widget<ReaderView>(find.byType(ReaderView)).embedded,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      expect(
        tester.widget<ReaderView>(find.byType(ReaderView)).embedded,
        isTrue,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(640, 900);
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      expect(
        tester.widget<ReaderView>(find.byType(ReaderView)).embedded,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      router.pop();
      await opened;
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
      expect(tester.takeException(), isNull);
    },
  );
}
