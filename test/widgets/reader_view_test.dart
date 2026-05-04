import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_ai_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/reader_providers.dart';
import 'package:fleur/providers/reader_search_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/repositories/tag_repository.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_progress_store.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/utils/tag_colors.dart';
import 'package:fleur/widgets/reader_bottom_bar.dart';
import 'package:fleur/widgets/reader_search_bar.dart';
import 'package:fleur/widgets/reader_view.dart';

import '../test_utils/critical_workflow_test_support.dart';

class _FakeFullTextController extends FullTextController {
  static int fetchCalls = 0;
  static Future<bool> Function(
    _FakeFullTextController controller,
    int articleId,
  )?
  onFetch;

  @override
  Future<void> build() async {}

  @override
  Future<bool> fetch(int articleId) async {
    fetchCalls++;
    final handler = onFetch;
    if (handler != null) {
      return handler(this, articleId);
    }
    return false;
  }
}

class _StubIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected Isar access: ${invocation.memberName}',
    );
  }
}

void main() {
  const articleId = 7;

  Future<void> settleReader(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Feed buildFeed() {
    return Feed()
      ..id = 70
      ..url = 'https://example.com/feed.xml'
      ..title = 'Feed'
      ..categoryId = 5;
  }

  Article buildArticle({
    String? html,
    bool isRead = false,
    String? contentHash = 'reader-hash',
  }) {
    return Article()
      ..id = articleId
      ..feedId = 70
      ..categoryId = 5
      ..link = 'https://example.com/article'
      ..title = 'Reader Article'
      ..contentHtml = html ?? '<p>Hello world</p>'
      ..contentHash = contentHash
      ..isRead = isRead
      ..publishedAt = DateTime.utc(2026, 1, 2)
      ..updatedAt = DateTime.utc(2026, 1, 2);
  }

  Future<void> pumpReader(
    WidgetTester tester, {
    required Article article,
    AppSettings? appSettings,
    ReaderSettings? readerSettings,
    TranslationAiSettings? translationSettings,
    RecordingArticleActionService? actionService,
    InMemoryReaderProgressStore? progressStore,
    InMemoryImageMetaStore? imageMetaStore,
    FakeTranslationService? translationService,
    ImmediateAiRequestQueue? aiQueue,
    InMemoryAiContentCacheStore? cacheStore,
    FakeTranslationAiSecretStore? secretStore,
    List<Override> extraOverrides = const <Override>[],
    Size size = const Size(800, 1200),
  }) async {
    _FakeFullTextController.onFetch = null;
    _FakeFullTextController.fetchCalls = 0;
    addTearDown(() => _FakeFullTextController.onFetch = null);

    await pumpLocalizedTestApp(
      tester,
      home: ReaderView(articleId: articleId),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(appSettings ?? AppSettings.defaults()),
        ),
        readerSettingsStoreProvider.overrideWithValue(
          FakeReaderSettingsStore(readerSettings ?? const ReaderSettings()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(
          FakeTranslationAiSettingsStore(
            translationSettings ?? TranslationAiSettings.defaults(),
          ),
        ),
        translationAiSecretStoreProvider.overrideWithValue(
          secretStore ?? FakeTranslationAiSecretStore(),
        ),
        articleProvider(articleId).overrideWith((ref) => Stream.value(article)),
        feedsProvider.overrideWith((ref) => Stream.value([buildFeed()])),
        readerProgressStoreProvider.overrideWithValue(
          progressStore ?? InMemoryReaderProgressStore(),
        ),
        imageMetaStoreProvider.overrideWithValue(
          imageMetaStore ?? InMemoryImageMetaStore(),
        ),
        articleActionServiceProvider.overrideWithValue(
          actionService ?? RecordingArticleActionService(),
        ),
        translationServiceProvider.overrideWithValue(
          translationService ?? FakeTranslationService(),
        ),
        aiContentCacheStoreProvider.overrideWithValue(
          cacheStore ?? InMemoryAiContentCacheStore(),
        ),
        aiRequestQueueProvider.overrideWithValue(
          aiQueue ?? ImmediateAiRequestQueue(),
        ),
        fullTextControllerProvider.overrideWith(_FakeFullTextController.new),
        ...extraOverrides,
      ],
      size: size,
    );
    await settleReader(tester, rounds: 8);
  }

  testWidgets('marks article as read when opening the reader', (tester) async {
    final actionService = RecordingArticleActionService();

    await pumpReader(
      tester,
      article: buildArticle(isRead: false),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: true),
      actionService: actionService,
    );

    expect(actionService.markReadCalls, [(articleId: articleId, isRead: true)]);
  });

  testWidgets(
    'reader title remains larger than body at default and large sizes',
    (tester) async {
      Future<double> pumpAndReadTitleSize(ReaderSettings settings) async {
        await pumpReader(
          tester,
          article: buildArticle(),
          appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
          readerSettings: settings,
        );

        final readerElement = tester.element(find.byType(ReaderView));
        final sceneTheme = AppTheme.readerScene(Theme.of(readerElement));
        final titleStyle = sceneTheme.fleurReader.titleStyleForBodyFontSize(
          settings.fontSize,
        );

        expect(titleStyle.fontSize, greaterThan(settings.fontSize));
        return titleStyle.fontSize ?? 0;
      }

      final defaultTitleSize = await pumpAndReadTitleSize(
        const ReaderSettings(),
      );
      final largeTitleSize = await pumpAndReadTitleSize(
        const ReaderSettings(fontSize: 28),
      );

      expect(largeTitleSize, greaterThan(defaultTitleSize));
      expect(largeTitleSize, lessThanOrEqualTo(40));
    },
  );

  testWidgets('full-text button triggers fetch from reader action', (
    tester,
  ) async {
    _FakeFullTextController.onFetch = (controller, _) async {
      return false;
    };

    await pumpReader(
      tester,
      article: buildArticle(),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );

    await tester.tap(find.byKey(const Key('reader_more_actions_button')));
    await tester.pump();
    await settleReader(tester, rounds: 2);
    await tester.tap(find.byKey(const Key('reader_overflow_full_text')).last);
    await tester.pump();
    await settleReader(tester, rounds: 4);
    expect(_FakeFullTextController.fetchCalls, 1);
  });

  testWidgets('reader settings open as a dialog on wide layouts', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      size: const Size(800, 1200),
    );

    await tester.tap(find.byKey(const Key('reader_more_actions_button')));
    await tester.pump();
    await settleReader(tester, rounds: 2);
    await tester.tap(find.byKey(const Key('reader_overflow_settings')).last);
    await tester.pump();
    await settleReader(tester, rounds: 4);

    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('reader settings open as a bottom sheet on narrow layouts', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      size: const Size(360, 800),
    );

    await tester.tap(find.byKey(const Key('reader_more_actions_button')));
    await tester.pump();
    await settleReader(tester, rounds: 2);
    await tester.tap(find.byKey(const Key('reader_overflow_settings')).last);
    await tester.pump();
    await settleReader(tester, rounds: 4);

    expect(find.text('Reader settings'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('reader bottom bar stays single-row on narrow layouts', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldOnError?.call(details);
    };

    try {
      await pumpReader(
        tester,
        article: buildArticle(),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
        size: const Size(320, 640),
      );

      expect(find.byKey(const Key('reader_translate_button')), findsOneWidget);
      expect(
        find.byKey(const Key('reader_more_actions_button')),
        findsOneWidget,
      );
      expect(find.byTooltip('Reader settings'), findsNothing);
      expect(find.byTooltip('Manage Tags'), findsNothing);

      await tester.tap(find.byKey(const Key('reader_more_actions_button')));
      await tester.pump();
      await settleReader(tester, rounds: 2);

      expect(find.byKey(const Key('reader_overflow_settings')), findsOneWidget);
      expect(find.byKey(const Key('reader_overflow_summary')), findsOneWidget);
      expect(
        find.byKey(const Key('reader_overflow_full_text')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reader_overflow_tags')), findsOneWidget);
      expect(find.byKey(const Key('reader_overflow_share')), findsOneWidget);
    } finally {
      FlutterError.onError = oldOnError;
    }

    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
  });

  testWidgets('translate button drives translation and find-in-page search', (
    tester,
  ) async {
    final translationService = FakeTranslationService(
      onTranslateText:
          ({
            required provider,
            required settings,
            required secrets,
            required text,
            required targetLanguageTag,
          }) async {
            return 'bonjour';
          },
    );

    await pumpReader(
      tester,
      article: buildArticle(
        html:
            '<p>Hello world repeated many times to make sure the reader '
            'AI flow detects English content reliably before translation. '
            'Hello world hello world hello world hello world.</p>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      translationSettings: TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: 'fr',
      ),
      translationService: translationService,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    await tester.tap(find.byKey(const Key('reader_translate_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Immersive translation').last);
    await settleReader(tester, rounds: 8);
    expect(
      container.read(articleAiControllerProvider(articleId)).translationHtml,
      contains('bonjour'),
    );

    container.read(readerSearchControllerProvider(articleId).notifier).open();
    container
        .read(readerSearchControllerProvider(articleId).notifier)
        .setQuery('bonjour');
    await settleReader(tester, rounds: 5);

    expect(find.text('Find in page'), findsOneWidget);
    expect(
      container.read(readerSearchControllerProvider(articleId)).totalMatches,
      1,
    );
  });

  testWidgets('saves reading progress after scrolling', (tester) async {
    final progressStore = InMemoryReaderProgressStore();
    final longHtml = List<String>.generate(
      300,
      (index) => '<p>Paragraph ${index + 1} ${'content ' * 32}</p>',
    ).join();
    final article = buildArticle(html: longHtml);

    await pumpReader(
      tester,
      article: article,
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      progressStore: progressStore,
      size: const Size(560, 320),
    );
    await settleReader(tester, rounds: 100);

    final scrollableStates = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where((state) => state.position.maxScrollExtent > 0)
        .toList(growable: false);
    expect(scrollableStates, isNotEmpty);
    final scrollableState = scrollableStates.first;
    final targetOffset = scrollableState.position.maxScrollExtent * 0.8;
    scrollableState.position.jumpTo(targetOffset);
    await settleReader(tester, rounds: 4);
    final firstScrollPosition = scrollableState.position.pixels;
    expect(firstScrollPosition, greaterThan(0));
    await settleReader(tester, rounds: 15);
    final saved = await progressStore.getProgress(
      articleId: articleId,
      contentHash: 'reader-hash',
    );
    expect(saved, isNotNull);
    expect(saved!.pixels, greaterThan(0));
  });

  testWidgets('reader scene applies themed search and toolbar surfaces', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    container.read(readerSearchControllerProvider(articleId).notifier).open();
    await settleReader(tester, rounds: 4);

    final bottomBarElement = tester.element(find.byType(ReaderBottomBar));
    final sceneTheme = Theme.of(bottomBarElement);
    final bottomBarContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ReaderBottomBar),
            matching: find.byType(Container),
          )
          .first,
    );
    final bottomBarDecoration = bottomBarContainer.decoration as BoxDecoration?;

    final searchBarMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ReaderSearchBar),
            matching: find.byWidgetPredicate(
              (widget) => widget is Material && widget.color != null,
            ),
          )
          .first,
    );

    expect(sceneTheme.scaffoldBackgroundColor, sceneTheme.fleurSurface.reader);
    expect(sceneTheme.cardTheme.color, sceneTheme.fleurReader.summarySurface);
    expect(bottomBarDecoration?.color, sceneTheme.fleurReader.toolbarSurface);
    expect(searchBarMaterial.color, sceneTheme.fleurReader.searchBarSurface);
    expect(find.text('Find in page'), findsOneWidget);
  });

  testWidgets('restores reading progress after reopening the article', (
    tester,
  ) async {
    final progressStore = InMemoryReaderProgressStore();
    final longHtml = List<String>.generate(
      300,
      (index) => '<p>Paragraph ${index + 1} ${'content ' * 32}</p>',
    ).join();
    final article = buildArticle(html: longHtml);
    await progressStore.saveProgress(
      ReaderProgress(
        articleId: articleId,
        contentHash: 'reader-hash',
        pixels: 900,
        progress: 0.45,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await pumpReader(
      tester,
      article: article,
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      progressStore: progressStore,
      size: const Size(560, 320),
    );

    await settleReader(tester, rounds: 100);
    final restoredPixels = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0)
        .position
        .pixels;
    final restoredScrollState = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    final expectedOffset = restoredScrollState.position.maxScrollExtent * 0.45;

    expect(restoredPixels, greaterThan(0));
    expect(restoredPixels, closeTo(expectedOffset, 40));
  });

  testWidgets(
    'manage tags dialog keeps 48dp color swatches with semantic labels',
    (tester) async {
      final stubIsar = _StubIsar();
      final tag = Tag()
        ..id = 1
        ..name = 'Important'
        ..color = kTagColorPalette.first;

      await pumpReader(
        tester,
        article: buildArticle(),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
        extraOverrides: [
          articleRepositoryProvider.overrideWithValue(
            ArticleRepository(stubIsar),
          ),
          tagRepositoryProvider.overrideWithValue(TagRepository(stubIsar)),
          tagsProvider.overrideWith((ref) => Stream.value([tag])),
          articleTagsProvider(
            articleId,
          ).overrideWith((ref) => Stream.value(<Tag>[])),
        ],
      );

      await tester.tap(find.byKey(const Key('reader_more_actions_button')));
      await tester.pump();
      await settleReader(tester, rounds: 2);
      await tester.tap(find.byKey(const Key('reader_overflow_tags')).last);
      await tester.pump();
      await settleReader(tester, rounds: 4);

      final colorLabel = 'Tag color: ${kTagColorPalette.first.toUpperCase()}';
      final tooltipFinder = find.byTooltip(colorLabel);
      expect(tooltipFinder, findsOneWidget);

      final colorTarget = find.descendant(
        of: tooltipFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 48 && widget.height == 48,
        ),
      );
      expect(colorTarget, findsOneWidget);
      expect(tester.getSize(colorTarget), const Size(48, 48));
      expect(
        find.descendant(of: tooltipFinder, matching: find.byIcon(Icons.check)),
        findsNothing,
      );

      await tester.tap(colorTarget);
      await tester.pump();
      await settleReader(tester, rounds: 2);

      expect(
        find.descendant(of: tooltipFinder, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    },
  );
}
