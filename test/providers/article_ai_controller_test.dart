@Tags(['global_logger'])
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_ai_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/ai/ai_request_queue.dart';
import 'package:fleur/services/cache/ai_content_cache_store.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/services/translation/article_translation.dart';
import 'package:fleur/services/translation/translation_service.dart';
import 'package:fleur/utils/language_detector.dart';
import 'package:fleur/utils/language_utils.dart';
import 'package:fleur/utils/path_manager.dart';

import '../test_utils/critical_workflow_test_support.dart';

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
  const articleId = 1;
  const accountId = 'article-ai-test';

  test('LanguageDetector returns canonical script-aware identities', () {
    expect(
      LanguageDetector.detectLanguageTag(
        '这是一个关于阅读体验和翻译设置的测试文本，这篇文章会重复一些词语，让系统更容易判断为简体中文内容。',
      ),
      'zh-Hans',
    );
    expect(
      LanguageDetector.detectLanguageTag(
        '這是一篇關於閱讀體驗與翻譯設定的測試文章，內容會重複幾次，讓系統更容易判斷為繁體中文。',
      ),
      'zh-Hant',
    );
    expect(LanguageDetector.detectLanguageTag('中文'), unknownLanguageTag);
  });

  Feed buildFeed() {
    return Feed()
      ..id = 10
      ..url = 'https://example.com/feed.xml'
      ..title = 'Example Feed'
      ..categoryId = 100;
  }

  Category buildCategory() {
    return Category()
      ..id = 100
      ..name = 'Tech';
  }

  Article buildArticle({
    String html = '<p>Hello world from Fleur.</p>',
    String? contentHash = 'hash-1',
  }) {
    return Article()
      ..id = articleId
      ..feedId = 10
      ..categoryId = 100
      ..link = 'https://example.com/article'
      ..title = 'Hello'
      ..contentHtml = html
      ..contentHash = contentHash
      ..publishedAt = DateTime.utc(2026, 1, 2)
      ..updatedAt = DateTime.utc(2026, 1, 2);
  }

  AiServiceConfig buildAiService({String id = 'svc-1', bool enabled = true}) {
    return AiServiceConfig(
      id: id,
      name: 'Test AI',
      apiType: AiServiceApiType.openAiResponses,
      baseUrl: 'https://example.com/v1/',
      defaultModel: 'gpt-test',
      enabled: enabled,
    );
  }

  Future<void> flushAsync() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ProviderContainer buildContainer({
    required Stream<Article?> articleStream,
    AppSettings? appSettings,
    TranslationAiSettings? translationSettings,
    FakeTranslationAiSecretStore? secrets,
    InMemoryAiContentCacheStore? cacheStore,
    ImmediateAiRequestQueue? queue,
    FakeAiServiceClient? aiClient,
    FakeTranslationService? translationService,
  }) {
    final appStore = FakeAppSettingsStore(
      appSettings ?? AppSettings.defaults(),
    );
    final settingsStore = FakeTranslationAiSettingsStore(
      translationSettings ?? TranslationAiSettings.defaults(),
    );
    final secretStore = secrets ?? FakeTranslationAiSecretStore();
    final cache = cacheStore ?? InMemoryAiContentCacheStore();
    final aiQueue = queue ?? ImmediateAiRequestQueue();
    final client = aiClient ?? FakeAiServiceClient();
    final translator = translationService ?? FakeTranslationService();

    final container = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWithValue(
          buildTestAccount(id: accountId, isPrimary: true),
        ),
        appSettingsStoreProvider.overrideWithValue(appStore),
        translationAiSettingsStoreProvider.overrideWithValue(settingsStore),
        translationAiSecretStoreProvider.overrideWithValue(secretStore),
        aiContentCacheStoreProvider.overrideWithValue(cache),
        aiRequestQueueProvider.overrideWithValue(aiQueue),
        aiServiceClientProvider.overrideWithValue(client),
        translationServiceProvider.overrideWithValue(translator),
        articleProvider(articleId).overrideWith((ref) => articleStream),
        feedsProvider.overrideWith((ref) => Stream.value([buildFeed()])),
        categoriesProvider.overrideWith(
          (ref) => Stream.value([buildCategory()]),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('inherits overridden article dependencies from nested scope', () async {
    final root = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWithValue(
          buildTestAccount(id: accountId, isPrimary: true),
        ),
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(
          FakeTranslationAiSettingsStore(TranslationAiSettings.defaults()),
        ),
      ],
    );
    addTearDown(root.dispose);

    final scoped = ProviderContainer(
      parent: root,
      overrides: [
        articleProvider(
          articleId,
        ).overrideWith((ref) => Stream.value(buildArticle())),
        feedsProvider.overrideWith((ref) => Stream.value([buildFeed()])),
        categoriesProvider.overrideWith(
          (ref) => Stream.value([buildCategory()]),
        ),
      ],
    );
    addTearDown(scoped.dispose);

    final sub = scoped.listen<ArticleAiState>(
      articleAiControllerProvider(articleId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await flushAsync();

    expect(
      scoped.read(articleAiControllerProvider(articleId)).articleId,
      articleId,
    );
  });

  test(
    'uses cached summary and reports outdated prompt without calling AI',
    () async {
      final article = buildArticle();
      const targetLanguageTag = 'zh-Hans';
      final service = buildAiService();
      final settings = TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: canonicalLanguageIdentityTag(targetLanguageTag),
        defaultAiServiceId: service.id,
        aiServices: [service],
        aiSummaryPrompt: 'new prompt {{content}}',
      );
      final cacheStore = InMemoryAiContentCacheStore();
      final currentPromptHash = 'old-prompt-hash';
      await cacheStore.write(
        AiContentCacheEntry(
          key: AiContentCacheKey.summary(
            accountId: accountId,
            articleId: article.id,
            targetLanguageTag: targetLanguageTag,
            aiServiceId: service.id,
          ),
          contentHash: 'hash-1',
          promptHash: currentPromptHash,
          data: 'cached summary',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final aiClient = FakeAiServiceClient();
      final container = buildContainer(
        articleStream: Stream.value(article),
        appSettings: AppSettings.defaults().copyWith(showAiSummary: true),
        translationSettings: settings,
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        cacheStore: cacheStore,
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.summaryStatus, ArticleAiTaskStatus.ready);
      expect(state.summaryText, 'cached summary');
      expect(state.summaryOutdated, isTrue);
      expect(aiClient.prompts, isEmpty);
    },
  );

  test('summary prompt samples both head and tail of long content', () async {
    final service = buildAiService();
    const headMarker = 'HEAD_MARKER';
    const middleMarker = 'MIDDLE_MARKER';
    const tailMarker = 'TAIL_MARKER';
    final html =
        '<p>$headMarker ${'a' * 26000}</p>'
        '<p>$middleMarker ${'b' * 26000}</p>'
        '<p>${'c' * 26000} $tailMarker</p>';
    final aiClient = FakeAiServiceClient();
    final container = buildContainer(
      articleStream: Stream.value(buildArticle(html: html)),
      translationSettings: TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: 'en',
        defaultAiServiceId: service.id,
        aiServices: [service],
      ),
      secrets: FakeTranslationAiSecretStore(
        aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
      ),
      aiClient: aiClient,
    );

    final sub = container.listen<ArticleAiState>(
      articleAiControllerProvider(articleId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(appSettingsProvider.future);
    await container.read(translationAiSettingsProvider.future);
    await flushAsync();
    await container
        .read(articleAiControllerProvider(articleId).notifier)
        .ensureSummary();
    await flushAsync();

    expect(aiClient.userPrompts, hasLength(1));
    expect(aiClient.userPrompts.single, contains(headMarker));
    expect(aiClient.userPrompts.single, contains(tailMarker));
    expect(aiClient.userPrompts.single, isNot(contains(middleMarker)));
    expect(aiClient.systemInstructions.single, isNotNull);
  });

  test('returns error when summary service is not configured', () async {
    final container = buildContainer(
      articleStream: Stream.value(buildArticle()),
      translationSettings: TranslationAiSettings.defaults(),
    );

    final sub = container.listen<ArticleAiState>(
      articleAiControllerProvider(articleId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(appSettingsProvider.future);
    await container.read(translationAiSettingsProvider.future);
    await flushAsync();
    await container
        .read(articleAiControllerProvider(articleId).notifier)
        .ensureSummary();
    await flushAsync();

    final state = container.read(articleAiControllerProvider(articleId));
    expect(state.summaryStatus, ArticleAiTaskStatus.error);
    expect(state.summaryError, isNotEmpty);
  });

  test(
    'shows language mismatch banner when source differs from target',
    () async {
      final service = buildAiService();
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html:
                '<p>This article is written in English with enough repeated '
                'latin words to trigger the language detector reliably. '
                'English text English text English text English text.</p>',
          ),
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'zh',
          defaultAiServiceId: service.id,
          aiServices: [service],
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.sourceLanguageTag, isNotNull);
      expect(state.targetLanguageTag, 'zh-Hans');
      expect(state.showLanguageMismatchBanner, isTrue);
    },
  );

  test(
    'does not show mismatch for equivalent english regional target tag',
    () async {
      final service = buildAiService();
      final translator = FakeTranslationService();
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html:
                '<p>This article is written in English with enough repeated '
                'latin words to trigger the language detector reliably. '
                'English text English text English text English text.</p>',
          ),
        ),
        appSettings: AppSettings.defaults().copyWith(autoTranslate: true),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'en-GB',
          defaultAiServiceId: service.id,
          aiServices: [service],
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        translationService: translator,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.sourceLanguageTag, 'en');
      expect(state.targetLanguageTag, 'en');
      expect(state.showLanguageMismatchBanner, isFalse);
      expect(translator.translatedInputs, isEmpty);
    },
  );

  test(
    'does not show mismatch for equivalent chinese target variants',
    () async {
      final service = buildAiService();
      final translator = FakeTranslationService();
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html:
                '<p>这是一篇关于翻译设置和阅读体验的测试文章，这篇文章会重复一些词语，让系统更容易判定为简体中文内容。'
                '这是一篇关于翻译设置和阅读体验的测试文章，这篇文章会重复一些词语，让系统更容易判定为简体中文内容。</p>',
          ),
        ),
        appSettings: AppSettings.defaults().copyWith(autoTranslate: true),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'zh-Hans-CN',
          defaultAiServiceId: service.id,
          aiServices: [service],
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        translationService: translator,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.sourceLanguageTag, 'zh-Hans');
      expect(state.targetLanguageTag, 'zh-Hans');
      expect(state.showLanguageMismatchBanner, isFalse);
      expect(translator.translatedInputs, isEmpty);
    },
  );

  test(
    'unknown source identity suppresses mismatch and auto translation',
    () async {
      final service = buildAiService();
      final translator = FakeTranslationService();
      final container = buildContainer(
        articleStream: Stream.value(buildArticle(html: '<p>中文</p>')),
        appSettings: AppSettings.defaults().copyWith(autoTranslate: true),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'fr',
          defaultAiServiceId: service.id,
          aiServices: [service],
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        translationService: translator,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.sourceLanguageTag, unknownLanguageTag);
      expect(state.showLanguageMismatchBanner, isFalse);
      expect(translator.translatedInputs, isEmpty);
    },
  );

  test(
    'falls back to supported UI locale while preserving target identity',
    () async {
      final service = buildAiService();
      final aiClient = FakeAiServiceClient();
      final container = buildContainer(
        articleStream: Stream.value(buildArticle()),
        appSettings: AppSettings.defaults().copyWith(
          localeTag: 'fr-FR',
          showAiSummary: true,
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          defaultAiServiceId: service.id,
          aiServices: [service],
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.targetLanguageTag, 'fr');

      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureSummary();
      await flushAsync();

      expect(aiClient.prompts, isNotEmpty);
      expect(aiClient.prompts.single, contains('French'));
    },
  );

  test('logs summary failures without prompt, body, or API key', () async {
    await _withTestLogger(() async {
      final service = buildAiService();
      final aiClient = FakeAiServiceClient(
        onGenerateText:
            ({
              required service,
              required apiKey,
              required systemInstruction,
              required userPrompt,
              required maxOutputTokens,
            }) async {
              throw StateError('summary upstream failed');
            },
      );
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(html: '<p>HTML_BODY_MARKER</p>'),
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'fr',
          defaultAiServiceId: service.id,
          aiServices: [service],
          aiSummaryPrompt: 'PROMPT_TEMPLATE_MARKER {{content}}',
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'api-key-secret'},
        ),
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureSummary(priority: AiRequestPriority.foreground);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.summaryStatus, ArticleAiTaskStatus.error);

      final contents = await _readActiveLog();
      expect(contents, contains('[W] [ai] Article AI task failed'));
      expect(contents, contains('operation=summarizeArticle'));
      expect(contents, contains('articleId=$articleId'));
      expect(contents, contains('providerKind=aiService'));
      expect(contents, contains('apiType=openAiResponses'));
      expect(contents, contains('serviceId=${service.id}'));
      expect(contents, contains('model=${service.defaultModel}'));
      expect(contents, contains('targetLanguageTag=fr'));
      expect(contents, contains('priority=foreground'));
      expect(contents, isNot(contains('PROMPT_TEMPLATE_MARKER')));
      expect(contents, isNot(contains('HTML_BODY_MARKER')));
      expect(contents, isNot(contains('api-key-secret')));
    });
  });

  test('logs translation failures without prompt, body, or API key', () async {
    await _withTestLogger(() async {
      final service = buildAiService();
      final aiClient = FakeAiServiceClient(
        onGenerateText:
            ({
              required service,
              required apiKey,
              required systemInstruction,
              required userPrompt,
              required maxOutputTokens,
            }) async {
              throw StateError('translation upstream failed');
            },
      );
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html:
                '<p>HTML_TRANSLATION_BODY_MARKER repeated english words '
                'for language detection.</p>',
          ),
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'fr',
          translationProvider: TranslationProviderSelection.aiService(
            service.id,
          ),
          defaultAiServiceId: service.id,
          aiServices: [service],
          aiTranslationPrompt: 'TRANSLATION_PROMPT_MARKER {{content}}',
        ),
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'api-key-secret'},
        ),
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureTranslation(
            mode: ArticleTranslationMode.immersive,
            priority: AiRequestPriority.foreground,
          );
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.translationStatus, ArticleAiTaskStatus.error);

      final contents = await _readActiveLog();
      expect(contents, contains('[W] [ai] Article AI task failed'));
      expect(contents, contains('operation=translateArticle'));
      expect(contents, contains('articleId=$articleId'));
      expect(contents, contains('providerKind=aiService'));
      expect(contents, contains('apiType=openAiResponses'));
      expect(contents, contains('serviceId=${service.id}'));
      expect(contents, contains('model=${service.defaultModel}'));
      expect(contents, contains('targetLanguageTag=fr'));
      expect(contents, contains('translationMode=immersive'));
      expect(contents, contains('priority=foreground'));
      expect(contents, isNot(contains('TRANSLATION_PROMPT_MARKER')));
      expect(contents, isNot(contains('HTML_TRANSLATION_BODY_MARKER')));
      expect(contents, isNot(contains('api-key-secret')));
    });
  });

  test('recomputes translation when article content changes', () async {
    final controller = StreamController<Article?>();
    addTearDown(controller.close);

    final service = buildAiService();
    final translator = FakeTranslationService(
      onTranslateText:
          ({
            required provider,
            required settings,
            required secrets,
            required text,
            required targetLanguageTag,
          }) async {
            return '[$targetLanguageTag] $text';
          },
    );
    final container = buildContainer(
      articleStream: controller.stream,
      appSettings: AppSettings.defaults().copyWith(autoTranslate: true),
      translationSettings: TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: 'zh',
        defaultAiServiceId: service.id,
        aiServices: [service],
      ),
      secrets: FakeTranslationAiSecretStore(
        aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
      ),
      translationService: translator,
    );

    final sub = container.listen<ArticleAiState>(
      articleAiControllerProvider(articleId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(appSettingsProvider.future);
    await container.read(translationAiSettingsProvider.future);
    controller.add(
      buildArticle(
        html:
            '<p>Hello world repeated many times to make sure the language '
            'detector sees enough latin letters for auto translation. '
            'Hello world hello world hello world hello world.</p>',
        contentHash: 'hash-1',
      ),
    );
    await flushAsync();
    await container
        .read(articleAiControllerProvider(articleId).notifier)
        .ensureTranslation(mode: ArticleTranslationMode.immersive);
    await flushAsync();

    var state = container.read(articleAiControllerProvider(articleId));
    expect(state.translationStatus, ArticleAiTaskStatus.ready);
    expect(state.translationHtml, contains('[zh-Hans] Hello world'));

    controller.add(
      buildArticle(html: '<p>Updated article text</p>', contentHash: 'hash-2'),
    );
    await flushAsync();

    state = container.read(articleAiControllerProvider(articleId));
    expect(state.translationStatus, ArticleAiTaskStatus.idle);
    expect(state.translationHtml, isNull);

    await container
        .read(articleAiControllerProvider(articleId).notifier)
        .ensureTranslation(mode: ArticleTranslationMode.immersive);
    await flushAsync();

    state = container.read(articleAiControllerProvider(articleId));
    expect(state.translationStatus, ArticleAiTaskStatus.ready);
    expect(state.translationHtml, contains('[zh-Hans] Updated article text'));
    expect(translator.translatedInputs, hasLength(2));
    expect(translator.translatedInputs.first, contains('Hello world'));
    expect(translator.translatedInputs.last, 'Updated article text');
  });

  test(
    'uses cached AI translation and marks outdated prompt contract',
    () async {
      final article = buildArticle();
      const targetLanguageTag = 'fr';
      final service = buildAiService();
      final settings = TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: canonicalLanguageIdentityTag(targetLanguageTag),
        translationProvider: TranslationProviderSelection.aiService(service.id),
        defaultAiServiceId: service.id,
        aiServices: [service],
        aiTranslationPrompt: 'custom translation {{content}}',
      );
      final cacheStore = InMemoryAiContentCacheStore();
      await cacheStore.write(
        AiContentCacheEntry(
          key: AiContentCacheKey.translation(
            accountId: accountId,
            articleId: article.id,
            targetLanguageTag: canonicalLanguageIdentityTag(targetLanguageTag),
            translationMode: ArticleTranslationMode.immersive,
            translationProviderKind: TranslationProviderKind.aiService.name,
            translationProviderServiceId: service.id,
          ),
          contentHash: 'hash-1',
          promptHash: 'legacy-prompt-hash',
          data: '<p>bonjour</p>',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final aiClient = FakeAiServiceClient();
      final container = buildContainer(
        articleStream: Stream.value(article),
        translationSettings: settings,
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        cacheStore: cacheStore,
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureTranslation(mode: ArticleTranslationMode.immersive);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.translationStatus, ArticleAiTaskStatus.ready);
      expect(state.translationHtml, '<p>bonjour</p>');
      expect(state.translationOutdated, isTrue);
      expect(aiClient.prompts, isEmpty);
    },
  );

  test(
    'translates container targets and appends immersive output inside them',
    () async {
      final translator = FakeTranslationService(
        onTranslateText:
            ({
              required provider,
              required settings,
              required secrets,
              required text,
              required targetLanguageTag,
            }) async {
              return '[$text]';
            },
      );
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html: '''
<blockquote>Quoted block text.</blockquote>
<figure><figcaption>Figure caption text.</figcaption></figure>
<table>
  <caption>Table caption text.</caption>
  <tbody>
    <tr>
      <td>Table cell text.</td>
      <th>Header cell text.</th>
    </tr>
  </tbody>
</table>
''',
          ),
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'zh',
        ),
        translationService: translator,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureTranslation(mode: ArticleTranslationMode.immersive);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.translationStatus, ArticleAiTaskStatus.ready);
      const expectedInputs = <String>[
        'Quoted block text.',
        'Figure caption text.',
        'Table caption text.',
        'Table cell text.',
        'Header cell text.',
      ];
      expect(translator.translatedInputs, expectedInputs);

      final translationHtml =
          state.translationHtml ?? fail('expected translationHtml');
      final fragment = html_parser.parseFragment(translationHtml);
      const selectors = <String>[
        'blockquote',
        'figcaption',
        'caption',
        'td',
        'th',
      ];
      for (var i = 0; i < selectors.length; i++) {
        final selector = selectors[i];
        final target = fragment.querySelector(selector);
        expect(target, isNotNull, reason: selector);
        final translation = target!.querySelector(
          '[data-fleur-translation="1"]',
        );
        expect(translation, isNotNull, reason: selector);
        expect(translation!.localName, 'div', reason: selector);
        expect(translation.text, '[${expectedInputs[i]}]');
      }
    },
  );

  test(
    'translates nested block leaves without translating container text',
    () async {
      final translator = FakeTranslationService(
        onTranslateText:
            ({
              required provider,
              required settings,
              required secrets,
              required text,
              required targetLanguageTag,
            }) async {
              return '[$text]';
            },
      );
      final container = buildContainer(
        articleStream: Stream.value(
          buildArticle(
            html: '''
<blockquote><p>Nested quote paragraph.</p></blockquote>
<table><tbody><tr><td><p>Nested cell paragraph.</p></td></tr></tbody></table>
''',
          ),
        ),
        translationSettings: TranslationAiSettings.defaults().copyWith(
          targetLanguageTag: 'zh',
        ),
        translationService: translator,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureTranslation(mode: ArticleTranslationMode.immersive);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.translationStatus, ArticleAiTaskStatus.ready);
      expect(translator.translatedInputs, <String>[
        'Nested quote paragraph.',
        'Nested cell paragraph.',
      ]);

      final translationHtml =
          state.translationHtml ?? fail('expected translationHtml');
      final fragment = html_parser.parseFragment(translationHtml);
      expect(
        fragment.querySelector('blockquote > div[data-fleur-translation="1"]'),
        isNull,
      );
      expect(
        fragment.querySelector('td > div[data-fleur-translation="1"]'),
        isNull,
      );
      expect(
        fragment.querySelectorAll('p + [data-fleur-translation="1"]'),
        hasLength(2),
      );
    },
  );

  test('skips translation targets inside pre and code blocks', () async {
    final translator = FakeTranslationService(
      onTranslateText:
          ({
            required provider,
            required settings,
            required secrets,
            required text,
            required targetLanguageTag,
          }) async {
            return '[$text]';
          },
    );
    final container = buildContainer(
      articleStream: Stream.value(
        buildArticle(
          html: '''
<pre><p>Do not translate pre paragraph.</p></pre>
<code><p>Do not translate code paragraph.</p></code>
<p>Translate normal paragraph.</p>
''',
        ),
      ),
      translationSettings: TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: 'zh',
      ),
      translationService: translator,
    );

    final sub = container.listen<ArticleAiState>(
      articleAiControllerProvider(articleId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(appSettingsProvider.future);
    await container.read(translationAiSettingsProvider.future);
    await flushAsync();
    await container
        .read(articleAiControllerProvider(articleId).notifier)
        .ensureTranslation(mode: ArticleTranslationMode.immersive);
    await flushAsync();

    final state = container.read(articleAiControllerProvider(articleId));
    expect(state.translationStatus, ArticleAiTaskStatus.ready);
    expect(translator.translatedInputs, <String>[
      'Translate normal paragraph.',
    ]);

    final translationHtml =
        state.translationHtml ?? fail('expected translationHtml');
    final fragment = html_parser.parseFragment(translationHtml);
    expect(fragment.querySelector('pre [data-fleur-translation="1"]'), isNull);
    expect(fragment.querySelector('code [data-fleur-translation="1"]'), isNull);
    expect(
      fragment.querySelector('p + [data-fleur-translation="1"]')?.text,
      '[Translate normal paragraph.]',
    );
  });

  test(
    'uses cached AI translation with missing prompt hash as outdated',
    () async {
      final article = buildArticle();
      const targetLanguageTag = 'fr';
      final service = buildAiService();
      final settings = TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: canonicalLanguageIdentityTag(targetLanguageTag),
        translationProvider: TranslationProviderSelection.aiService(service.id),
        defaultAiServiceId: service.id,
        aiServices: [service],
        aiTranslationPrompt: 'custom translation {{content}}',
      );
      final cacheStore = InMemoryAiContentCacheStore();
      await cacheStore.write(
        AiContentCacheEntry(
          key: AiContentCacheKey.translation(
            accountId: accountId,
            articleId: article.id,
            targetLanguageTag: canonicalLanguageIdentityTag(targetLanguageTag),
            translationMode: ArticleTranslationMode.immersive,
            translationProviderKind: TranslationProviderKind.aiService.name,
            translationProviderServiceId: service.id,
          ),
          contentHash: 'hash-1',
          promptHash: null,
          data: '<p>bonjour legacy</p>',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final aiClient = FakeAiServiceClient();
      final container = buildContainer(
        articleStream: Stream.value(article),
        translationSettings: settings,
        secrets: FakeTranslationAiSecretStore(
          aiServiceApiKeys: <String, String>{service.id: 'secret-key'},
        ),
        cacheStore: cacheStore,
        aiClient: aiClient,
      );

      final sub = container.listen<ArticleAiState>(
        articleAiControllerProvider(articleId),
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(appSettingsProvider.future);
      await container.read(translationAiSettingsProvider.future);
      await flushAsync();
      await container
          .read(articleAiControllerProvider(articleId).notifier)
          .ensureTranslation(mode: ArticleTranslationMode.immersive);
      await flushAsync();

      final state = container.read(articleAiControllerProvider(articleId));
      expect(state.translationStatus, ArticleAiTaskStatus.ready);
      expect(state.translationHtml, '<p>bonjour legacy</p>');
      expect(state.translationOutdated, isTrue);
      expect(aiClient.prompts, isEmpty);
    },
  );

  test(
    'translation service maps canonical chinese identities for providers',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final host = options.uri.host;
            final path = options.uri.path;

            if (host == 'translate.googleapis.com') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: '[[["google-ok"]]]',
                ),
              );
              return;
            }

            if (host == 'edge.microsoft.com' && path == '/translate/auth') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: 'token',
                ),
              );
              return;
            }

            if (host == 'api-edge.cognitive.microsofttranslator.com' &&
                path == '/translate') {
              handler.resolve(
                Response<List<dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'translations': [
                        {'text': 'bing-ok'},
                      ],
                    },
                  ],
                ),
              );
              return;
            }

            if (host == 'fanyi-api.baidu.com') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: '{"trans_result":[{"dst":"baidu-ok"}]}',
                ),
              );
              return;
            }

            if (host == 'api.deepl.com' && path == '/v2/translate') {
              handler.resolve(
                Response<Map<String, Object?>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, Object?>{
                    'translations': [
                      <String, Object?>{'text': 'deepl-ok'},
                    ],
                  },
                ),
              );
              return;
            }

            handler.reject(DioException(requestOptions: options));
          },
        ),
      );

      final service = TranslationService(dio: dio);
      final secrets = FakeTranslationAiSecretStore(
        deepLApiKey: 'deep-key',
        baiduCredentials: (appId: 'app-id', appKey: 'app-key'),
      );
      final settings = TranslationAiSettings.defaults().copyWith(
        deepL: const DeepLSettings(endpoint: DeepLEndpoint.pro),
      );

      await service.translateText(
        provider: const TranslationProviderSelection.googleWeb(),
        settings: settings,
        secrets: secrets,
        text: 'hello',
        targetLanguageTag: 'zh-Hans-CN',
      );
      await service.translateText(
        provider: const TranslationProviderSelection.bingWeb(),
        settings: settings,
        secrets: secrets,
        text: 'hello',
        targetLanguageTag: 'zh-Hant-HK',
      );
      await service.translateText(
        provider: const TranslationProviderSelection.baiduApi(),
        settings: settings,
        secrets: secrets,
        text: 'hello',
        targetLanguageTag: 'zh-Hans-CN',
      );
      await service.translateText(
        provider: const TranslationProviderSelection.deepLApi(),
        settings: settings,
        secrets: secrets,
        text: 'hello',
        targetLanguageTag: 'zh-Hant-HK',
      );

      final googleRequest = requests.firstWhere(
        (request) => request.uri.host == 'translate.googleapis.com',
      );
      expect(googleRequest.uri.queryParameters['tl'], 'zh-CN');

      final bingRequest = requests.firstWhere(
        (request) =>
            request.uri.host == 'api-edge.cognitive.microsofttranslator.com',
      );
      expect(bingRequest.uri.queryParameters['to'], 'zh-Hant');

      final baiduRequest = requests.firstWhere(
        (request) => request.uri.host == 'fanyi-api.baidu.com',
      );
      expect((baiduRequest.data as Map<String, Object?>)['to'], 'zh');

      final deepLRequest = requests.firstWhere(
        (request) => request.uri.host == 'api.deepl.com',
      );
      expect(
        (deepLRequest.data as Map<String, Object?>)['target_lang'],
        'ZH-HANT',
      );
    },
  );
}

Future<T> _withTestLogger<T>(Future<T> Function() body) async {
  final previousPlatform = PathProviderPlatform.instance;
  final tempDir = await Directory.systemTemp.createTemp(
    'fleur_article_ai_logger_test_',
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
