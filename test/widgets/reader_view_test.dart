import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_ai_providers.dart';
import 'package:fleur/providers/favicon_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/reader_providers.dart';
import 'package:fleur/providers/reader_search_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/repositories/tag_repository.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_progress_store.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/services/feed_html_normalizer.dart';
import 'package:fleur/services/html_sanitizer.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/reader/reader_selectable_rich_text.dart';
import 'package:fleur/ui/reader/code_rendering/reader_code_rendering.dart';
import 'package:fleur/utils/content_hash.dart';
import 'package:fleur/utils/path_manager.dart';
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

class _TranslatedArticleAiController extends ArticleAiController {
  @override
  ArticleAiState build(int articleId) {
    return ArticleAiState.initial(articleId).copyWith(
      translationHtml: '<p>Translated body</p>',
      translationStatus: ArticleAiTaskStatus.ready,
    );
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

class _NoopCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected cache manager access: ${invocation.memberName}',
    );
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
    required String temporaryPath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath,
       _temporaryPath = temporaryPath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;
  final String _temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}

void main() {
  const articleId = 7;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> settleReader(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int attempts = 50,
  }) async {
    for (var i = 0; i < attempts; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) return;
    }
    expect(condition(), isTrue);
  }

  ScrollableState verticalReaderScrollable(WidgetTester tester) {
    return tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere(
          (state) =>
              state.position.axis == Axis.vertical &&
              state.position.maxScrollExtent > 0,
        );
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
    String? title,
    bool isRead = false,
    String? contentHash = 'reader-hash',
  }) {
    return Article()
      ..id = articleId
      ..feedId = 70
      ..categoryId = 5
      ..link = 'https://example.com/article'
      ..title = title ?? 'Reader Article'
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
        cacheManagerProvider.overrideWithValue(_NoopCacheManager()),
        faviconUrlProvider.overrideWith((ref, hostKey) async => null),
        faviconFileProvider.overrideWith((ref, url) async => null),
        fullTextControllerProvider.overrideWith(_FakeFullTextController.new),
        ...extraOverrides,
      ],
      size: size,
    );
    await settleReader(tester, rounds: 8);
  }

  double expectedReaderContentLeft(
    WidgetTester tester,
    ReaderSettings settings,
  ) {
    final readerElement = tester.element(find.byType(ReaderView));
    final sceneTheme = AppTheme.readerScene(
      Theme.of(readerElement),
      settings: settings,
    );
    final reader = sceneTheme.fleurReader;
    final readerViewWidth = tester.getSize(find.byType(ReaderView)).width;
    final readingWidth = math.min(readerViewWidth, reader.maxWidth);
    final horizontalPadding = math.max(
      settings.horizontalPadding,
      reader.contentPaddingHorizontal,
    );
    return (readerViewWidth - readingWidth) / 2 + horizontalPadding;
  }

  String displayedContentHash(String html) {
    return ContentHash.compute(
      HtmlSanitizer.sanitize(
        normalizeReaderHtmlForDisplay(
          FeedHtmlNormalizer.normalize(
            html,
            baseUrl: Uri.parse('https://example.com/article'),
          ),
        ),
      ),
    );
  }

  String readerPlainText(WidgetTester tester) {
    return tester
        .widgetList<ReaderSelectableRichText>(
          find.descendant(
            of: find.byType(HtmlWidget),
            matching: find.byType(ReaderSelectableRichText),
          ),
        )
        .map((widget) => widget.text.toPlainText())
        .join('\n');
  }

  List<TextSpan> flattenTextSpans(TextSpan span) {
    return [
      span,
      for (final child in span.children ?? const <InlineSpan>[])
        if (child is TextSpan) ...flattenTextSpans(child),
    ];
  }

  List<List<ReaderSelectableRichText>> readerCodeLines(WidgetTester tester) {
    return [
      for (final block in find.byKey(const Key('reader_code_block')).evaluate())
        tester
            .widgetList<ReaderSelectableRichText>(
              find.descendant(
                of: find.byElementPredicate((element) => element == block),
                matching: find.byKey(const Key('reader_code_line_code')),
              ),
            )
            .toList(growable: false),
    ];
  }

  List<String> readerCodePlainTexts(WidgetTester tester) {
    return [
      for (final lines in readerCodeLines(tester))
        lines.map((widget) => widget.text.toPlainText()).join('\n'),
    ];
  }

  List<TextSpan> readerCodeTextSpans(WidgetTester tester) {
    return [
      for (final lines in readerCodeLines(tester))
        for (final widget in lines)
          if (widget.text is TextSpan)
            ...flattenTextSpans(widget.text as TextSpan),
    ];
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

  testWidgets('missing article shows reader empty feedback', (tester) async {
    await pumpLocalizedTestApp(
      tester,
      home: const ReaderView(articleId: articleId),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        readerSettingsStoreProvider.overrideWithValue(
          FakeReaderSettingsStore(const ReaderSettings()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(
          FakeTranslationAiSettingsStore(TranslationAiSettings.defaults()),
        ),
        translationAiSecretStoreProvider.overrideWithValue(
          FakeTranslationAiSecretStore(),
        ),
        articleProvider(articleId).overrideWith((ref) => Stream.value(null)),
        readerProgressStoreProvider.overrideWithValue(
          InMemoryReaderProgressStore(),
        ),
        imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
        fullTextControllerProvider.overrideWith(_FakeFullTextController.new),
      ],
      size: const Size(800, 1200),
    );
    await settleReader(tester, rounds: 4);

    final element = tester.element(find.byType(ReaderView));
    final l10n = AppLocalizations.of(element)!;

    expect(find.text(l10n.notFound), findsOneWidget);
    expect(find.text(l10n.articleNotFoundSubtitle), findsOneWidget);
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

  testWidgets('reader body defaults to compact long-form typography', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html: '<p>Long form body copy should stay quiet and readable.</p>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    final bodyFinder = find.descendant(
      of: find.byType(HtmlWidget),
      matching: find.byType(ReaderSelectableRichText),
    );
    expect(bodyFinder, findsWidgets);

    final bodyText = tester.widget<ReaderSelectableRichText>(bodyFinder.first);
    final span = bodyText.text as TextSpan;
    final style = span.style!;

    expect(style.fontSize, ReaderSettings.defaultFontSize);
    expect(style.height, ReaderSettings.defaultLineHeight);
    expect(style.fontWeight, FontWeight.w400);

    final readerElement = tester.element(find.byType(ReaderView));
    final reader = AppTheme.readerScene(Theme.of(readerElement)).fleurReader;
    expect(style.color, reader.bodyStyle.color);
  });

  testWidgets('reader sanitizes feed html before rendering and search', (
    tester,
  ) async {
    final rawHtml =
        '<p onclick="evil()">Visible safe text</p>'
        '<script>needleUnsafe()</script>'
        '<p>Searchable clean text</p>';

    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: rawHtml),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    final plainText = readerPlainText(tester);
    expect(plainText, contains('Visible safe text'));
    expect(plainText, isNot(contains('needleUnsafe')));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    container.read(readerSearchControllerProvider(articleId).notifier).open();
    container
        .read(readerSearchControllerProvider(articleId).notifier)
        .setQuery('needleUnsafe');
    await settleReader(tester, rounds: 5);

    expect(
      container.read(readerSearchControllerProvider(articleId)).totalMatches,
      0,
    );

    container
        .read(readerSearchControllerProvider(articleId).notifier)
        .setQuery('Searchable clean text');
    await settleReader(tester, rounds: 5);

    expect(
      container.read(readerSearchControllerProvider(articleId)).totalMatches,
      1,
    );
  });

  testWidgets('reader display html prefers extracted content over feed', (
    tester,
  ) async {
    final article = buildArticle(title: 'A', html: '<p>Feed body</p>')
      ..extractedContentHtml = '<p>Extracted body</p>'
      ..preferredContentView = ArticleContentView.feed;

    await pumpReader(
      tester,
      article: article,
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    final plainText = readerPlainText(tester);
    expect(plainText, contains('Extracted body'));
    expect(plainText, isNot(contains('Feed body')));
  });

  testWidgets(
    'reader display html prefers translation over extracted content',
    (tester) async {
      final article = buildArticle(title: 'A', html: '<p>Feed body</p>')
        ..extractedContentHtml = '<p>Extracted body</p>';

      await pumpReader(
        tester,
        article: article,
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
        extraOverrides: [
          articleAiControllerProvider.overrideWith(
            _TranslatedArticleAiController.new,
          ),
        ],
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 12);

      final plainText = readerPlainText(tester);
      expect(plainText, contains('Translated body'));
      expect(plainText, isNot(contains('Extracted body')));
    },
  );

  testWidgets('reader applies theme styles to rich html elements', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<blockquote><p>Quoted body</p></blockquote>'
            '<pre><code>final answer = 42;</code></pre>'
            '<table><tr><th>Name</th><td>Fleur</td></tr></table>'
            '<ul><li>Item one</li></ul>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    final readerElement = tester.element(find.byType(ReaderView));
    final reader = AppTheme.readerScene(Theme.of(readerElement)).fleurReader;

    final decoratedBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .toList(growable: false);
    final hasBlockquoteAccent = decoratedBoxes.any((widget) {
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final border = decoration.border;
      if (border is! Border) return false;
      return border.left.color == reader.blockquoteAccent &&
          border.left.width == 4;
    });
    final hasCodeSurface = decoratedBoxes.any((widget) {
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == reader.codeBlockSurface;
    });

    expect(hasBlockquoteAccent, isTrue);
    expect(hasCodeSurface, isTrue);
    expect(
      find.textContaining('Quoted body', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('final answer', findRichText: true),
      findsOneWidget,
    );
    final plainText = readerPlainText(tester);
    expect(plainText, contains('Name'));
    expect(plainText, contains('Item one'));
  });

  testWidgets('reader renders math nodes and skips code and links', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            r'<p>Inline $a^2+b^2=c^2$ math.</p>'
            r'<p>Block $$E = mc^2$$ math.</p>'
            r'<pre><code>$not_math$</code></pre>'
            r'<p><a href="https://example.com">$link_math$</a></p>'
            r'<p>Broken $\notACommand{$ formula.</p>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 16);

    expect(find.byKey(const Key('reader_math_node')), findsWidgets);
    expect(find.byKey(const Key('reader_math_block')), findsOneWidget);
    expect(find.byKey(const Key('reader_math_fallback')), findsOneWidget);
    expect(
      find.textContaining(r'$not_math$', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(r'$link_math$', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'reader renders code block with language marker and fallback text',
    (tester) async {
      await pumpReader(
        tester,
        article: buildArticle(
          title: 'A',
          html:
              '<pre>&lt;div class="box"&gt;\n'
              '  &lt;p id="p"&gt;我的对齐是？&lt;/p&gt;\n'
              '&lt;/div&gt;</pre>'
              '<pre><code class="language-css">'
              '@container excel-scroller scroll-state(scrolled: right) {\n'
              '/* first sticky column right border */\n'
              ':where(td, th):first-child {\n'
              '  border-right: 1px solid var(--ui-border);\n'
              '}\n'
              '}'
              '</code></pre>'
              '<pre><code class="language-typescript">'
              "import { createLogger } from 'vite'\n"
              'const logger = createLogger()'
              '</code></pre>'
              '<pre><code class="language-diff-plain language-diff diff-highlight">'
              '+added line\n'
              '-removed line\n'
              ' unchanged'
              '</code></pre>'
              '<pre><code class="language-unknown">plain fallback</code></pre>',
        ),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 20);

      expect(find.byKey(const Key('reader_code_block')), findsNWidgets(5));
      expect(
        find.textContaining('@container excel-scroller', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('createLogger', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('+added line', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('<div class="box">', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('plain fallback', findRichText: true),
        findsOneWidget,
      );

      final spans = readerCodeTextSpans(tester);
      final baseCodeColor = Theme.of(
        tester.element(find.byType(ReaderView)),
      ).colorScheme.onSurface;
      expect(
        spans.any(
          (span) =>
              (span.text?.contains('import') ?? false) &&
              span.style?.color != null &&
              span.style?.color != baseCodeColor,
        ),
        isTrue,
      );
      final addedDiffSpan = spans.firstWhere(
        (span) => span.text?.startsWith('+added line') ?? false,
      );
      final removedDiffSpan = spans.firstWhere(
        (span) => span.text?.startsWith('-removed line') ?? false,
      );
      expect(addedDiffSpan.style?.backgroundColor, isNotNull);
      expect(addedDiffSpan.style?.color, isNot(baseCodeColor));
      expect(removedDiffSpan.style?.backgroundColor, isNotNull);
      expect(removedDiffSpan.style?.color, isNot(baseCodeColor));
      expect(
        spans
            .map((span) => span.style)
            .whereType<TextStyle>()
            .where(
              (style) =>
                  style.decoration != null ||
                  style.fontStyle != null ||
                  style.fontWeight != null,
            ),
        everyElement(
          predicate<TextStyle>(
            (style) =>
                style.decoration == TextDecoration.none &&
                style.fontStyle == FontStyle.normal &&
                style.fontWeight == FontWeight.w400,
          ),
        ),
      );
    },
  );

  testWidgets('reader preserves structured code line breaks and language candidates', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<pre class="prism-code language-jsx"><code class="codeBlockLines_e6Vv">'
            '<span class="token-line"><span>import</span><span> React;</span><br></span>'
            '<span class="token-line"><span style="display: inline-block;"></span><br></span>'
            '<span class="token-line"><span>export default App;</span><br></span>'
            '</code></pre>'
            '<pre><code>a<br>b</code></pre>'
            '<pre><code><div>first line</div><div>second line</div></code></pre>'
            '<pre><code class="language-text language-jsx">'
            'const value = 1;\n'
            'function demo() { return value; }'
            '</code></pre>'
            '<pre><code class="language-jsx">'
            '<span class="token keyword">import</span>'
            '<span class="token plain"> </span>'
            '<span class="token function">demo</span>'
            '<span class="token punctuation">()</span>'
            '</code></pre>'
            '<pre><code class="language-js">'
            '<span class="hljs-keyword">const</span>'
            '<span> value = </span>'
            '<span class="hljs-string">"ok"</span>'
            '</code></pre>'
            '<pre><code class="language-tsx">'
            '<span style="color:#ff0000">inlineRed</span>'
            '<span style="color: rgb(0, 128, 0)">inlineGreen</span>'
            '</code></pre>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 20);

    final codeTexts = readerCodePlainTexts(tester);
    expect(codeTexts, hasLength(7));
    expect(codeTexts[0], "import React;\n\nexport default App;");
    expect(codeTexts[0], isNot(contains(';export')));
    expect(codeTexts[1], 'a\nb');
    expect(codeTexts[2], 'first line\nsecond line');
    expect(codeTexts[3], 'const value = 1;\nfunction demo() { return value; }');
    final lineNumbers = tester
        .widgetList<Text>(find.byKey(const Key('reader_code_line_number')))
        .map((widget) => widget.data)
        .toList(growable: false);
    expect(lineNumbers.take(3), ['1', '2', '3']);
    expect(lineNumbers.skip(3).take(2), ['1', '2']);
    expect(lineNumbers.skip(5).take(2), ['1', '2']);

    await pumpUntil(tester, () {
      final lines = readerCodeLines(tester)[3];
      return lines
          .where((line) => line.text is TextSpan)
          .expand((line) => flattenTextSpans(line.text as TextSpan))
          .any(
            (span) =>
                (span.text?.contains('const') ?? false) &&
                span.style?.color != null,
          );
    }, attempts: 80);

    await pumpUntil(tester, () {
      final spans = readerCodeTextSpans(tester);
      return spans.any(
            (span) => span.text == 'import' && span.style?.color != null,
          ) &&
          spans.any(
            (span) => span.text == '"ok"' && span.style?.color != null,
          ) &&
          spans.any(
            (span) =>
                span.text == 'inlineRed' &&
                span.style?.color == const Color(0xFFFF0000),
          );
    }, attempts: 80);

    final spans = readerCodeTextSpans(tester);
    expect(
      spans.any((span) => span.text == 'import' && span.style?.color != null),
      isTrue,
    );
    expect(
      spans.any((span) => span.text == '"ok"' && span.style?.color != null),
      isTrue,
    );
    expect(
      spans.any(
        (span) =>
            span.text == 'inlineRed' &&
            span.style?.color == const Color(0xFFFF0000),
      ),
      isTrue,
    );
  });

  testWidgets(
    'reader code block header copies text and line numbers stay separate',
    (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          });

      await pumpReader(
        tester,
        article: buildArticle(
          title: 'A',
          html:
              '<pre><code class="language-text language-jsx">const value = 1;\n\nreturn value;</code></pre>'
              '<pre><code class="language-plain">plain text</code></pre>',
        ),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 12);

      expect(find.byKey(const Key('reader_code_block')), findsNWidgets(2));
      expect(find.byKey(const Key('reader_code_header')), findsNWidgets(2));
      expect(find.text('jsx'), findsOneWidget);
      expect(find.text('plain'), findsNothing);
      expect(
        find.byTooltip(
          MaterialLocalizations.of(
            tester.element(find.byType(ReaderView)),
          ).copyButtonLabel,
        ),
        findsNWidgets(2),
      );

      final lineNumbers = tester
          .widgetList<Text>(find.byKey(const Key('reader_code_line_number')))
          .map((widget) => widget.data)
          .toList(growable: false);
      expect(lineNumbers, ['1', '2', '3', '1']);
      expect(readerCodePlainTexts(tester), [
        'const value = 1;\n\nreturn value;',
        'plain text',
      ]);

      await tester.tap(find.byKey(const Key('reader_code_copy_button')).first);
      await tester.pump();

      expect(clipboardText, 'const value = 1;\n\nreturn value;');
      expect(clipboardText, isNot(contains('jsx')));
      expect(clipboardText, isNot(contains('1\n2\n3')));
      expect(
        find.byKey(const Key('reader_code_copy_success_icon')),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          AppLocalizations.of(
            tester.element(find.byType(ReaderView)),
          )!.copiedToClipboard,
        ),
        findsOneWidget,
      );

      await tester.pump(ReaderCodeBlockChrome.copyFeedbackDuration);
      await tester.pump();

      expect(find.byKey(const Key('reader_code_copy_icon')), findsNWidgets(2));
    },
  );

  testWidgets(
    'reader labels high-confidence code guesses and hides low-confidence labels',
    (tester) async {
      await pumpReader(
        tester,
        article: buildArticle(
          title: 'A',
          html:
              '<pre>const ref = new WeakRef({ data: "heavy resource" });\n'
              'console.log(ref.deref()?.data);</pre>'
              '<pre>echo hi</pre>',
        ),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 12);

      expect(find.byKey(const Key('reader_code_block')), findsNWidgets(2));
      expect(find.text('javascript'), findsOneWidget);
      expect(find.text('shell'), findsNothing);
      expect(readerCodePlainTexts(tester), [
        'const ref = new WeakRef({ data: "heavy resource" });\nconsole.log(ref.deref()?.data);',
        'echo hi',
      ]);

      await pumpUntil(tester, () {
        final firstBlockLines = readerCodeLines(tester).first;
        return firstBlockLines
            .where((line) => line.text is TextSpan)
            .expand((line) => flattenTextSpans(line.text as TextSpan))
            .any((span) => span.text == 'const' && span.style?.color != null);
      }, attempts: 80);

      final lowConfidenceChildSpans = readerCodeLines(tester).last.expand((
        line,
      ) {
        final text = line.text;
        return text is TextSpan
            ? (text.children ?? const <InlineSpan>[]).whereType<TextSpan>()
            : const <TextSpan>[];
      });
      expect(
        lowConfidenceChildSpans.any((span) => span.style?.color != null),
        isFalse,
      );
    },
  );

  testWidgets(
    'reader code line gutter shares text metrics and sizes to line digits',
    (tester) async {
      final shortCode = List<String>.generate(
        9,
        (index) => 'shortLine${index + 1};',
      ).join('\n');
      final longCode = List<String>.generate(
        120,
        (index) => 'longLine${index + 1};',
      ).join('\n');

      await pumpReader(
        tester,
        article: buildArticle(
          title: 'A',
          html:
              '<pre><code class="language-js">$shortCode</code></pre>'
              '<pre><code class="language-js">$longCode</code></pre>',
        ),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 12);

      final codeLines = readerCodeLines(tester);
      final lineNumbers = tester
          .widgetList<Text>(find.byKey(const Key('reader_code_line_number')))
          .toList(growable: false);
      expect(codeLines, hasLength(2));
      expect(codeLines[0], hasLength(9));
      expect(codeLines[1], hasLength(120));
      expect(lineNumbers, hasLength(129));
      for (var i = 0; i < lineNumbers.length; i++) {
        final codeLine = i < 9 ? codeLines[0][i] : codeLines[1][i - 9];
        expect(lineNumbers[i].strutStyle, codeLine.strutStyle);
        expect(lineNumbers[i].textHeightBehavior, codeLine.textHeightBehavior);
      }
      expect(codeLines.first.first.strutStyle?.forceStrutHeight, isTrue);
      expect(
        codeLines.first.first.textHeightBehavior?.applyHeightToFirstAscent,
        isFalse,
      );
      expect(
        codeLines.first.first.textHeightBehavior?.applyHeightToLastDescent,
        isFalse,
      );

      final gutterSizes = tester
          .widgetList<Container>(
            find.byKey(const Key('reader_code_line_gutter')),
          )
          .map((widget) => widget.constraints!.maxWidth)
          .toList(growable: false);
      expect(gutterSizes, hasLength(2));
      expect(gutterSizes[1], greaterThan(gutterSizes[0]));
      expect(lineNumbers.last.data, '120');

      final firstBlock = find.byKey(const Key('reader_code_block')).first;
      final firstBlockNumbers = tester
          .widgetList<Text>(
            find.descendant(
              of: firstBlock,
              matching: find.byKey(const Key('reader_code_line_number')),
            ),
          )
          .toList(growable: false);
      final firstBlockLines = tester
          .widgetList<ReaderSelectableRichText>(
            find.descendant(
              of: firstBlock,
              matching: find.byKey(const Key('reader_code_line_code')),
            ),
          )
          .toList(growable: false);
      for (var i = 0; i < firstBlockLines.length; i++) {
        final numberBox = tester.getRect(find.byWidget(firstBlockNumbers[i]));
        final codeBox = tester.getRect(find.byWidget(firstBlockLines[i]));
        expect(numberBox.top, moreOrLessEquals(codeBox.top, epsilon: 0.01));
        expect(
          numberBox.bottom,
          moreOrLessEquals(codeBox.bottom, epsilon: 0.01),
        );
      }

      final gutter = tester.widget<Container>(
        find.byKey(const Key('reader_code_line_gutter')).first,
      );
      final decoration = gutter.decoration! as BoxDecoration;
      final border = decoration.border! as BorderDirectional;
      expect(border.end.width, 1);
    },
  );

  testWidgets('reader highlights and scrolls to code search matches', (
    tester,
  ) async {
    final leadingHtml = List<String>.generate(
      18,
      (index) => '<p>Intro paragraph ${index + 1} ${'content ' * 24}</p>',
    ).join();

    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '$leadingHtml'
            '<pre class="language-jsx"><code>'
            '<span class="token-line"><span>const targetAlpha = 1;</span><br></span>'
            '<span class="token-line"><span>const targetBeta = 2;</span><br></span>'
            '</code></pre>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      size: const Size(560, 320),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 20);

    expect(find.byKey(const Key('reader_code_block')), findsOneWidget);
    final readerScrollable = verticalReaderScrollable(tester);
    expect(readerScrollable.position.pixels, 0);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderView)),
    );
    final controller = container.read(
      readerSearchControllerProvider(articleId).notifier,
    );
    controller.open();
    controller.setQuery('target');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 6);
    await pumpUntil(
      tester,
      () => find.byKey(const Key('reader_code_block')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('reader_code_block')), findsOneWidget);
    expect(
      container.read(readerSearchControllerProvider(articleId)).totalMatches,
      2,
    );
    await pumpUntil(
      tester,
      () => readerCodeTextSpans(tester).any(
        (span) =>
            (span.text?.contains('target') ?? false) &&
            span.style?.backgroundColor != null,
      ),
      attempts: 80,
    );
    await pumpUntil(
      tester,
      () => readerScrollable.position.pixels > 0,
      attempts: 80,
    );

    final firstCurrent = readerCodeTextSpans(tester).firstWhere(
      (span) =>
          (span.text?.contains('target') ?? false) &&
          span.style?.backgroundColor != null,
    );
    expect(firstCurrent.style?.backgroundColor, isNotNull);

    controller.nextMatch();
    await settleReader(tester, rounds: 8);

    final targetSpans = readerCodeTextSpans(tester)
        .where(
          (span) =>
              (span.text?.contains('target') ?? false) &&
              span.style?.backgroundColor != null,
        )
        .toList(growable: false);
    expect(targetSpans, hasLength(2));
    expect(
      targetSpans.map((span) => span.style?.backgroundColor).toSet(),
      hasLength(2),
    );
  });

  testWidgets('reader renders media tags as cards', (tester) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<iframe src="https://www.youtube.com/embed/abc"></iframe>'
            '<video><source src="https://cdn.example.com/movie.mp4" type="video/mp4"></video>'
            '<audio src="https://cdn.example.com/sound.mp3"></audio>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    expect(find.byKey(const Key('reader_media_embed_card')), findsNWidgets(3));
    expect(find.text('Embedded media'), findsOneWidget);
    expect(find.text('Video media'), findsOneWidget);
    expect(find.text('Audio media'), findsOneWidget);
    expect(find.text('www.youtube.com'), findsOneWidget);
    expect(find.text('cdn.example.com'), findsNWidgets(2));
  });

  testWidgets('reader renders normalized feed demo content as static UI', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<p>CSS contrast-color()函数是专为无障碍访问设计的。</p>'
            '<pre>contrast-color(red)\ncontrast-color(var(--backgroundColor))</pre>'
            '<div class="contrast-x">'
            '<style>.contrast-x { button { color: contrast-color(red); } }</style>'
            '<p>请改变背景色：<input type="color" value="#336699" oninput="bad()"></p>'
            '<p><button onclick="bad()">我是按钮</button></p>'
            '</div>'
            '<p><img src="//image.zhangxinxu.com/image/blog/demo.gif" width="228" height="225" alt="自动配色按钮示意"></p>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 20);

    expect(
      find.textContaining('CSS contrast-color()', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reader_code_block')), findsNWidgets(2));
    expect(readerCodePlainTexts(tester), [
      'contrast-color(red)\ncontrast-color(var(--backgroundColor))',
      '.contrast-x { button { color: contrast-color(red); } }',
    ]);
    expect(find.text('css'), findsNWidgets(2));
    expect(find.byKey(const Key('reader_inert_color_input')), findsOneWidget);
    expect(find.byKey(const Key('reader_inert_button')), findsOneWidget);
    expect(find.text('我是按钮'), findsOneWidget);
    expect(readerPlainText(tester), isNot(contains('bad()')));
  });

  testWidgets('reader renders table caption and footer with theme styling', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<table><caption>Metrics</caption><thead><tr><th>Name</th></tr></thead>'
            '<tbody><tr><td>Fleur</td></tr></tbody><tfoot><tr><td>Total</td></tr></tfoot></table>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    final plainText = readerPlainText(tester);
    expect(plainText, contains('Metrics'));
    expect(plainText, contains('Total'));
    expect(find.byType(HtmlWidget), findsOneWidget);
  });

  testWidgets('reader shows image error placeholder when image fails', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<p><img src="https://example.invalid/missing.png" '
            'alt="Missing diagram" width="240" height="120"></p>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    expect(
      find.byKey(const Key('reader_image_error_placeholder')),
      findsOneWidget,
    );
    expect(find.text('Missing diagram'), findsOneWidget);
    expect(find.byIcon(FleurIcons.brokenImage), findsOneWidget);
  });

  testWidgets('reader renders trusted iframe as media card only', (
    tester,
  ) async {
    await pumpReader(
      tester,
      article: buildArticle(
        title: 'A',
        html:
            '<iframe src="https://www.youtube.com/embed/abc"></iframe>'
            '<iframe src="https://evil.example/embed/abc"></iframe>',
      ),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settleReader(tester, rounds: 12);

    expect(find.byKey(const Key('reader_media_embed_card')), findsOneWidget);
    expect(find.text('Embedded media'), findsOneWidget);
    expect(find.text('www.youtube.com'), findsOneWidget);
    expect(find.textContaining('evil.example'), findsNothing);
  });

  testWidgets('reader timestamp stays small metadata', (tester) async {
    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: '<p>B</p>'),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
    );

    final dateText = find.textContaining('2026/01/02');
    expect(dateText, findsOneWidget);

    final timestamp = tester.widget<Text>(dateText);
    final style = timestamp.style!;

    expect(style.fontSize, 12);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.letterSpacing, 0);
    expect(style.height, 1.2);
  });

  testWidgets('short reader content starts at the left edge of the measure', (
    tester,
  ) async {
    const settings = ReaderSettings(horizontalPadding: 20);

    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: '<p>B</p>'),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      readerSettings: settings,
      size: const Size(1000, 800),
    );

    final expectedLeft = expectedReaderContentLeft(tester, settings);
    final titleFinder = find.text('A');
    final bodyFinder = find.byType(HtmlWidget);

    expect(titleFinder, findsOneWidget);
    expect(bodyFinder, findsOneWidget);
    expect(tester.getTopLeft(titleFinder).dx, closeTo(expectedLeft, 1));
    expect(tester.getTopLeft(bodyFinder).dx, closeTo(expectedLeft, 1));
  });

  testWidgets('reader width preset changes the reading measure', (
    tester,
  ) async {
    const settings = ReaderSettings(
      horizontalPadding: 20,
      contentWidthPreset: ReaderContentWidthPreset.wide,
    );

    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: '<p>B</p>'),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      readerSettings: settings,
      size: const Size(1000, 800),
    );

    final expectedLeft = expectedReaderContentLeft(tester, settings);

    expect(tester.getTopLeft(find.text('A')).dx, closeTo(expectedLeft, 1));
    expect(expectedLeft, closeTo(90, 1));
  });

  testWidgets('reader applies selected reader theme surface', (tester) async {
    const settings = ReaderSettings(readerTheme: ReaderThemePreset.sepia);

    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: '<p>B</p>'),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      readerSettings: settings,
    );

    final htmlElement = tester.element(find.byType(HtmlWidget));
    final theme = Theme.of(htmlElement);

    expect(theme.fleurSurface.reader, const Color(0xFFF3E7D2));
    expect(theme.fleurReader.bodyStyle.color, isNotNull);
    expect(
      theme.fleurReader.bodyStyle.color,
      isNot(AppTheme.light().colorScheme.onSurface),
    );
  });

  testWidgets(
    'reader html text uses strut-backed selection boxes for mixed scripts',
    (tester) async {
      const settings = ReaderSettings(
        fontSize: 18,
        lineHeight: 1.7,
        horizontalPadding: 20,
      );
      final mixedText = List<String>.filled(
        4,
        '中文 English 123, punctuation !?「」 mixed symbols ',
      ).join();

      await pumpReader(
        tester,
        article: buildArticle(title: 'A', html: '<p>$mixedText</p>'),
        appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
        readerSettings: settings,
        size: const Size(420, 800),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settleReader(tester, rounds: 12);

      final richTextFinder = find.descendant(
        of: find.byType(HtmlWidget),
        matching: find.byType(ReaderSelectableRichText),
      );

      expect(richTextFinder, findsWidgets);
      final renderObject = tester.renderObject<ReaderSelectionRenderParagraph>(
        richTextFinder.first,
      );
      expect(renderObject.selectionHeightStyle, ui.BoxHeightStyle.strut);

      final text = renderObject.text.toPlainText();
      final boxes = renderObject.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      final heights = boxes
          .map((box) => box.toRect().height)
          .where((height) => height > 0)
          .toList();

      expect(boxes.length, greaterThan(1));
      expect(heights, isNotEmpty);
      for (final height in heights) {
        expect(height, closeTo(heights.first, 0.01));
      }
    },
  );

  testWidgets('chunked reader content keeps the same left edge', (
    tester,
  ) async {
    const settings = ReaderSettings(horizontalPadding: 20);
    final longHtml = List<String>.generate(
      900,
      (index) => '<p>Chunk ${index + 1} ${'content ' * 8}</p>',
    ).join();

    await pumpReader(
      tester,
      article: buildArticle(title: 'A', html: longHtml),
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      readerSettings: settings,
      size: const Size(1000, 800),
    );
    await settleReader(tester, rounds: 20);

    final expectedLeft = expectedReaderContentLeft(tester, settings);
    final titleFinder = find.text('A');

    expect(titleFinder, findsOneWidget);
    expect(tester.getTopLeft(titleFinder).dx, closeTo(expectedLeft, 1));
    expect(find.byType(ListView), findsOneWidget);
  });

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

    await tester.tap(find.byKey(const Key('reader_full_text_button')));
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
      expect(find.byKey(const Key('reader_full_text_button')), findsOneWidget);
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
      expect(find.byKey(const Key('reader_overflow_full_text')), findsNothing);
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

  test('reader tag operation failures are logged without tag names', () async {
    await _withTestLogger(() async {
      logReaderTagFailureForTest(
        operation: 'toggleTag',
        articleId: articleId,
        tagId: 11,
        selected: true,
        error: StateError('tag toggle failed'),
        stackTrace: StackTrace.current,
      );
      logReaderTagFailureForTest(
        operation: 'deleteTag',
        articleId: articleId,
        tagId: 11,
        error: StateError('tag delete failed'),
        stackTrace: StackTrace.current,
      );

      final contents = await _readActiveLog();
      expect(contents, contains('[W] [tag] Reader tag operation failed'));
      expect(contents, contains('operation=toggleTag'));
      expect(contents, contains('operation=deleteTag'));
      expect(contents, contains('articleId=$articleId'));
      expect(contents, contains('tagId=11'));
      expect(contents, contains('selected=true'));
      expect(contents, isNot(contains('Private Tag Name')));
    });
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
    expect(progressStore.entries, hasLength(1));
    final saved = progressStore.entries.single;
    expect(saved.contentHash, displayedContentHash(longHtml));
    expect(saved, isNotNull);
    expect(saved.pixels, greaterThan(0));
  });

  testWidgets('saves chunk anchor with reading progress', (tester) async {
    final progressStore = InMemoryReaderProgressStore();
    final chunkedHtml = List<String>.generate(
      180,
      (index) => '<p>Chunk paragraph ${index + 1} ${'content ' * 72}</p>',
    ).join();
    final article = buildArticle(html: chunkedHtml);

    await pumpReader(
      tester,
      article: article,
      appSettings: AppSettings.defaults().copyWith(autoMarkRead: false),
      progressStore: progressStore,
      size: const Size(560, 320),
    );
    await settleReader(tester, rounds: 100);

    final scrollableState = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    scrollableState.position.jumpTo(
      scrollableState.position.maxScrollExtent * 0.5,
    );
    await settleReader(tester, rounds: 20);

    expect(progressStore.entries, hasLength(1));
    final saved = progressStore.entries.single;
    expect(saved.contentHash, displayedContentHash(chunkedHtml));
    expect(saved, isNotNull);
    expect(saved.pixels, greaterThan(0));
    expect(saved.anchorIndex, isNotNull);
    expect(saved.anchorFraction, isNotNull);
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
    expect(
      tester.getSize(find.byKey(const Key('reader_feed_icon'))),
      const Size(32, 32),
    );
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
        contentHash: displayedContentHash(longHtml),
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
        find.descendant(
          of: tooltipFinder,
          matching: find.byIcon(FleurIcons.check),
        ),
        findsNothing,
      );

      await tester.tap(colorTarget);
      await tester.pump();
      await settleReader(tester, rounds: 2);

      expect(
        find.descendant(
          of: tooltipFinder,
          matching: find.byIcon(FleurIcons.check),
        ),
        findsOneWidget,
      );
    },
  );
}

Future<T> _withTestLogger<T>(Future<T> Function() body) async {
  final previousPlatform = PathProviderPlatform.instance;
  final tempDir = await Directory.systemTemp.createTemp(
    'fleur_reader_logger_test_',
  );
  try {
    final documents = await Directory(
      '${tempDir.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir.path}/cache',
    ).create(recursive: true);
    final temporary = await Directory(
      '${tempDir.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documents.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
    await AppLogger.resetForTests();
    await AppLogger.ensureInitialized();
    return await body();
  } finally {
    await AppLogger.resetForTests();
    PathManager.resetForTests();
    PathProviderPlatform.instance = previousPlatform;
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // ignore: best-effort cleanup
    }
  }
}

Future<String> _readActiveLog() async {
  final logFile = await AppLogger.getActiveLogFile();
  await AppLogger.resetForTests();
  return logFile!.readAsString();
}
