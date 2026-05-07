import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../l10n/app_localizations.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../services/ai/ai_request_queue.dart';
import '../services/cache/ai_content_cache_store.dart';
import '../services/logging/app_logger.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/translation_ai_settings.dart';
import '../services/translation/article_translation.dart';
import '../utils/content_hash.dart';
import '../utils/language_detector.dart';
import '../utils/language_utils.dart';
import '../utils/prompt_template.dart';
import '../utils/token_estimator.dart';
import 'account_providers.dart';
import 'app_settings_providers.dart';
import 'query_providers.dart';
import 'service_providers.dart';
import 'translation_ai_settings_providers.dart';

enum ArticleAiTaskStatus { idle, queued, running, ready, error }

class ArticleAiState {
  const ArticleAiState({
    required this.articleId,
    required this.contentHash,
    required this.targetLanguageTag,
    required this.sourceLanguageTag,
    required this.showLanguageMismatchBanner,
    required this.summaryText,
    required this.summaryStatus,
    required this.summaryError,
    required this.summaryOutdated,
    required this.translationHtml,
    required this.translationMode,
    required this.translationStatus,
    required this.translationError,
    required this.translationOutdated,
  });

  factory ArticleAiState.initial(int articleId) {
    return ArticleAiState(
      articleId: articleId,
      contentHash: '',
      targetLanguageTag: 'und',
      sourceLanguageTag: null,
      showLanguageMismatchBanner: false,
      summaryText: null,
      summaryStatus: ArticleAiTaskStatus.idle,
      summaryError: null,
      summaryOutdated: false,
      translationHtml: null,
      translationMode: null,
      translationStatus: ArticleAiTaskStatus.idle,
      translationError: null,
      translationOutdated: false,
    );
  }

  final int articleId;
  final String contentHash;
  final String targetLanguageTag;
  final String? sourceLanguageTag;
  final bool showLanguageMismatchBanner;

  final String? summaryText;
  final ArticleAiTaskStatus summaryStatus;
  final String? summaryError;
  final bool summaryOutdated;

  final String? translationHtml;
  final ArticleTranslationMode? translationMode;
  final ArticleAiTaskStatus translationStatus;
  final String? translationError;
  final bool translationOutdated;

  ArticleAiState copyWith({
    String? contentHash,
    String? targetLanguageTag,
    Object? sourceLanguageTag = _unset,
    bool? showLanguageMismatchBanner,
    Object? summaryText = _unset,
    ArticleAiTaskStatus? summaryStatus,
    Object? summaryError = _unset,
    bool? summaryOutdated,
    Object? translationHtml = _unset,
    Object? translationMode = _unset,
    ArticleAiTaskStatus? translationStatus,
    Object? translationError = _unset,
    bool? translationOutdated,
  }) {
    return ArticleAiState(
      articleId: articleId,
      contentHash: contentHash ?? this.contentHash,
      targetLanguageTag: targetLanguageTag ?? this.targetLanguageTag,
      sourceLanguageTag: sourceLanguageTag == _unset
          ? this.sourceLanguageTag
          : sourceLanguageTag as String?,
      showLanguageMismatchBanner:
          showLanguageMismatchBanner ?? this.showLanguageMismatchBanner,
      summaryText: summaryText == _unset
          ? this.summaryText
          : summaryText as String?,
      summaryStatus: summaryStatus ?? this.summaryStatus,
      summaryError: summaryError == _unset
          ? this.summaryError
          : summaryError as String?,
      summaryOutdated: summaryOutdated ?? this.summaryOutdated,
      translationHtml: translationHtml == _unset
          ? this.translationHtml
          : translationHtml as String?,
      translationMode: translationMode == _unset
          ? this.translationMode
          : translationMode as ArticleTranslationMode?,
      translationStatus: translationStatus ?? this.translationStatus,
      translationError: translationError == _unset
          ? this.translationError
          : translationError as String?,
      translationOutdated: translationOutdated ?? this.translationOutdated,
    );
  }
}

const Object _unset = Object();
const String _summaryPromptContractVersion = 'summary-v2';
const String _translationPromptContractVersion = 'translation-v2';
const String _summarySystemInstruction = '''
You are a careful article summarizer.
Use only the information provided by the user prompt.
Return only the final summary in plain text.
Keep the summary concise, factual, and easy to scan.
Follow the target language requested in the user prompt.
Do not add preambles like "Summary:" unless the article content itself requires it.
''';
const String _translationSystemInstruction = '''
You are translating a single article fragment, not an entire article.
Return only the translated fragment in plain text.
Do not add explanations, notes, or surrounding quotation marks.
Do not wrap the result in code fences or markup.
Preserve proper nouns, numbers, URLs, and the original formatting intent when possible.
Follow the target language requested in the user prompt.
''';

final articleAiControllerProvider =
    AutoDisposeNotifierProviderFamily<ArticleAiController, ArticleAiState, int>(
      ArticleAiController.new,
      dependencies: [
        articleProvider,
        appSettingsProvider,
        translationAiSettingsProvider,
        feedMapProvider,
        categoriesProvider,
        activeAccountProvider,
        aiRequestQueueProvider,
        aiServiceClientProvider,
        translationServiceProvider,
        aiContentCacheStoreProvider,
        translationAiSecretStoreProvider,
      ],
    );

class ArticleAiController
    extends AutoDisposeFamilyNotifier<ArticleAiState, int> {
  Article? _article;
  Feed? _feed;
  Category? _category;
  AppSettings _appSettings = AppSettings.defaults();
  TranslationAiSettings? _translationSettings;
  AppLocalizations? _l10n;
  Locale _uiLocale = supportedAppLocaleForTag(
    defaultTargetLanguageTagForAppLocale(
      null,
      PlatformDispatcher.instance.locale,
    ),
  );
  String _defaultTargetLanguageTag = 'en';
  String _targetLanguageTag = 'und';
  String _activeHtml = '';
  bool _activeShowExtracted = false;
  String _contentHash = '';
  int _contentHashRequestId = 0;
  int _summaryRequestId = 0;
  int _translationRequestId = 0;

  @override
  ArticleAiState build(int articleId) {
    state = ArticleAiState.initial(articleId);

    ref.onDispose(() {
      _contentHashRequestId++;
      _summaryRequestId++;
      _translationRequestId++;
    });

    ref.listen<AsyncValue<Article?>>(
      articleProvider(articleId),
      (_, next) => _handleArticle(next.valueOrNull),
      fireImmediately: true,
    );
    ref.listen<AsyncValue<AppSettings>>(
      appSettingsProvider,
      (_, next) => _handleAppSettings(next.valueOrNull),
      fireImmediately: true,
    );
    ref.listen<AsyncValue<TranslationAiSettings>>(
      translationAiSettingsProvider,
      (_, next) => _handleTranslationSettings(next.valueOrNull),
      fireImmediately: true,
    );
    ref.listen<Map<int, Feed>>(feedMapProvider, (_, next) {
      final feedId = _article?.feedId;
      _feed = feedId == null ? null : next[feedId];
      _refreshAuto();
      _refreshLanguageBanner();
    }, fireImmediately: true);
    ref.listen<AsyncValue<List<Category>>>(categoriesProvider, (_, next) {
      final categories = next.valueOrNull ?? const <Category>[];
      final catId = _effectiveCategoryId();
      _category = catId == null
          ? null
          : categories.where((c) => c.id == catId).firstOrNull;
      _refreshAuto();
      _refreshLanguageBanner();
    }, fireImmediately: true);

    return state;
  }

  int? _effectiveCategoryId() {
    final feedCatId = _feed?.categoryId;
    if (feedCatId != null) return feedCatId;
    return _article?.categoryId;
  }

  void _handleAppSettings(AppSettings? next) {
    _appSettings = (next ?? AppSettings.defaults()).normalized();
    final runtimeTag = runtimeLanguageTagForAppLocale(
      _appSettings.localeTag,
      PlatformDispatcher.instance.locale,
    );
    _uiLocale = supportedAppLocaleForTag(runtimeTag);
    _defaultTargetLanguageTag = defaultTargetLanguageTagForAppLocale(
      _appSettings.localeTag,
      PlatformDispatcher.instance.locale,
    );
    _l10n = lookupAppLocalizations(_uiLocale);
    _refreshTargetLanguage();
    _refreshLanguageBanner();
    _refreshAuto();
  }

  void _handleTranslationSettings(TranslationAiSettings? next) {
    _translationSettings = next;
    _refreshTargetLanguage();
    _refreshLanguageBanner();
    _refreshAuto();
  }

  void _refreshTargetLanguage() {
    final settings = _translationSettings;
    final rawTarget = settings?.targetLanguageTag;
    final resolved = rawTarget == null || rawTarget.trim().isEmpty
        ? _defaultTargetLanguageTag
        : canonicalLanguageIdentityTag(rawTarget);
    _targetLanguageTag = resolved == unknownLanguageTag
        ? _defaultTargetLanguageTag
        : resolved;
    if (state.targetLanguageTag != _targetLanguageTag) {
      _summaryRequestId++;
      _translationRequestId++;
      state = state.copyWith(
        targetLanguageTag: _targetLanguageTag,
        summaryText: null,
        summaryStatus: ArticleAiTaskStatus.idle,
        summaryError: null,
        summaryOutdated: false,
        translationHtml: null,
        translationMode: null,
        translationStatus: ArticleAiTaskStatus.idle,
        translationError: null,
        translationOutdated: false,
      );
    }
  }

  void _handleArticle(Article? next) {
    _article = next;
    if (next == null) {
      _contentHashRequestId++;
      _summaryRequestId++;
      _translationRequestId++;
      _activeHtml = '';
      _activeShowExtracted = false;
      _contentHash = '';
      state = state.copyWith(
        contentHash: '',
        sourceLanguageTag: null,
        showLanguageMismatchBanner: false,
        summaryText: null,
        summaryStatus: ArticleAiTaskStatus.idle,
        summaryError: null,
        summaryOutdated: false,
        translationHtml: null,
        translationMode: null,
        translationStatus: ArticleAiTaskStatus.idle,
        translationError: null,
        translationOutdated: false,
      );
      return;
    }

    final hasExtracted = (next.extractedContentHtml ?? '').trim().isNotEmpty;
    final showExtracted =
        hasExtracted &&
        next.preferredContentView == ArticleContentView.extracted;
    final html =
        ((showExtracted ? next.extractedContentHtml : null) ??
                next.contentHtml ??
                '')
            .trim();

    final changed =
        html != _activeHtml || showExtracted != _activeShowExtracted;
    _activeHtml = html;
    _activeShowExtracted = showExtracted;

    if (changed) {
      _summaryRequestId++;
      _translationRequestId++;
      _contentHash = '';
      state = state.copyWith(
        contentHash: '',
        summaryText: null,
        summaryStatus: ArticleAiTaskStatus.idle,
        summaryError: null,
        summaryOutdated: false,
        translationHtml: null,
        translationMode: null,
        translationStatus: ArticleAiTaskStatus.idle,
        translationError: null,
        translationOutdated: false,
      );
      _detectSourceLanguage(html);
      _requestContentHashUpdate(next, html, showExtracted: showExtracted);
      return;
    }

    _detectSourceLanguage(html);

    if (_contentHash.isEmpty) {
      _requestContentHashUpdate(next, html, showExtracted: showExtracted);
    } else {
      _refreshAuto();
    }
  }

  void _detectSourceLanguage(String html) {
    final text = _extractPlainText(html);
    final detected = LanguageDetector.detectLanguageTag(text);
    state = state.copyWith(sourceLanguageTag: detected);
    _refreshLanguageBanner();
  }

  void _refreshLanguageBanner() {
    final source = canonicalKnownLanguageTagOrNull(state.sourceLanguageTag);
    final target = canonicalKnownLanguageTagOrNull(_targetLanguageTag);
    final disabled =
        _translationSettings?.disabledTranslationReminderLanguages ??
        const <String>[];
    final shouldShow =
        source != null &&
        target != null &&
        source != target &&
        !disabled.contains(source) &&
        state.translationStatus == ArticleAiTaskStatus.idle &&
        state.translationHtml == null;
    state = state.copyWith(showLanguageMismatchBanner: shouldShow);
  }

  void _requestContentHashUpdate(
    Article article,
    String html, {
    required bool showExtracted,
  }) {
    if (!showExtracted) {
      final stored = (article.contentHash ?? '').trim();
      if (stored.isNotEmpty) {
        _setContentHash(stored);
        return;
      }
    }
    if (html.isEmpty) {
      _setContentHash('');
      return;
    }
    final requestId = ++_contentHashRequestId;
    unawaited(_computeContentHashAsync(html, requestId));
  }

  void _setContentHash(String hash) {
    _contentHash = hash;
    if (state.contentHash != hash) {
      state = state.copyWith(contentHash: hash);
    }
    _refreshAuto();
  }

  Future<void> _computeContentHashAsync(String html, int requestId) async {
    final hash = html.length >= 50000
        ? await compute(_computeContentHashInIsolate, html)
        : ContentHash.compute(html);
    if (requestId != _contentHashRequestId) return;
    _setContentHash(hash);
  }

  static String _computeContentHashInIsolate(String html) {
    return ContentHash.compute(html);
  }

  bool _effectiveAutoSummary() {
    final feedV = _feed?.showAiSummary;
    if (feedV != null) return feedV;
    final catV = _category?.showAiSummary;
    if (catV != null) return catV;
    return _appSettings.showAiSummary;
  }

  bool _effectiveAutoTranslate() {
    final feedV = _feed?.autoTranslate;
    if (feedV != null) return feedV;
    final catV = _category?.autoTranslate;
    if (catV != null) return catV;
    return _appSettings.autoTranslate;
  }

  void _refreshAuto() {
    final article = _article;
    final settings = _translationSettings;
    if (article == null || settings == null) return;
    if (_contentHash.trim().isEmpty) return;

    final queue = ref.read(aiRequestQueueProvider);
    queue.updateTpmLimit(settings.tpmLimit);

    if (_effectiveAutoSummary() &&
        state.summaryStatus == ArticleAiTaskStatus.idle &&
        (state.summaryText ?? '').trim().isEmpty) {
      unawaited(ensureSummary(priority: AiRequestPriority.foreground));
    }

    if (_effectiveAutoTranslate() &&
        state.translationStatus == ArticleAiTaskStatus.idle &&
        (state.translationHtml ?? '').trim().isEmpty) {
      final source = canonicalKnownLanguageTagOrNull(state.sourceLanguageTag);
      final target = canonicalKnownLanguageTagOrNull(_targetLanguageTag);
      if (source != null && target != null && source != target) {
        unawaited(
          ensureTranslation(
            mode: ArticleTranslationMode.immersive,
            priority: AiRequestPriority.foreground,
          ),
        );
      }
    }
  }

  Future<void> disableLanguageMismatchReminder() async {
    final source = canonicalKnownLanguageTagOrNull(state.sourceLanguageTag);
    if (source == null || source.isEmpty) return;
    await ref
        .read(translationAiSettingsProvider.notifier)
        .disableTranslationReminderForLanguage(source);
  }

  Future<void> ensureSummary({
    bool force = false,
    AiRequestPriority priority = AiRequestPriority.foreground,
  }) async {
    final requestId = ++_summaryRequestId;
    final article = _article;
    final settings = _translationSettings;
    final l10n = _l10n;
    if (article == null || settings == null || l10n == null) return;
    final contentHash = _contentHash.trim();
    if (contentHash.isEmpty) return;

    final serviceId =
        (settings.aiSummaryServiceId ?? settings.defaultAiServiceId ?? '')
            .trim();
    if (serviceId.isEmpty) {
      state = state.copyWith(
        summaryStatus: ArticleAiTaskStatus.error,
        summaryError: l10n.aiNotConfigured,
      );
      return;
    }

    final service = settings.aiServices
        .where((s) => s.id == serviceId)
        .firstOrNull;
    if (service == null || !service.enabled) {
      state = state.copyWith(
        summaryStatus: ArticleAiTaskStatus.error,
        summaryError: l10n.aiNotConfigured,
      );
      return;
    }

    final template = (settings.aiSummaryPrompt ?? '').trim().isNotEmpty
        ? settings.aiSummaryPrompt!.trim()
        : l10n.defaultAiSummaryPromptTemplate(
            PromptTemplate.token(PromptTemplate.varLanguage),
            PromptTemplate.token(PromptTemplate.varTitle),
            PromptTemplate.token(PromptTemplate.varContent),
          );
    final promptHash = _promptContractHash(
      version: _summaryPromptContractVersion,
      systemInstruction: _summarySystemInstruction,
      userTemplate: template,
    );

    final accountId = ref.read(activeAccountProvider).id;
    final cacheKey = AiContentCacheKey.summary(
      accountId: accountId,
      articleId: article.id,
      targetLanguageTag: _targetLanguageTag,
      aiServiceId: serviceId,
    );
    final cacheStore = ref.read(aiContentCacheStoreProvider);
    final cached = await cacheStore.read(cacheKey);
    if (requestId != _summaryRequestId) return;
    if (cached != null && cached.contentHash == contentHash) {
      final cachedText = cached.data.trim();
      if (cachedText.isNotEmpty) {
        final outdated = cached.promptHash != promptHash;
        state = state.copyWith(
          summaryText: cachedText,
          summaryStatus: ArticleAiTaskStatus.ready,
          summaryError: null,
          summaryOutdated: outdated,
        );
        if (!force && !outdated) return;
        if (!force && outdated) return;
      }
    } else if (cached != null && cached.contentHash != contentHash) {
      unawaited(cacheStore.delete(cacheKey));
    }

    final secrets = ref.read(translationAiSecretStoreProvider);
    final apiKey = await secrets.getAiServiceApiKey(serviceId);
    if (requestId != _summaryRequestId) return;
    if (apiKey == null || apiKey.trim().isEmpty) {
      state = state.copyWith(
        summaryStatus: ArticleAiTaskStatus.error,
        summaryError: l10n.aiNotConfigured,
      );
      return;
    }

    final title = (article.title ?? '').trim().isNotEmpty
        ? article.title!.trim()
        : article.link;
    final languageName = localizedLanguageNameForTag(
      _uiLocale,
      _targetLanguageTag,
    );
    final content = _extractPlainText(_activeHtml);
    final sampledContent = _sampleSummaryContent(content);
    final userPrompt = PromptTemplate.render(
      template,
      variables: <String, String>{
        PromptTemplate.varContent: sampledContent,
        PromptTemplate.varLanguage: languageName,
        PromptTemplate.varTitle: title,
      },
    );

    state = state.copyWith(
      summaryStatus: ArticleAiTaskStatus.queued,
      summaryError: null,
    );

    final queue = ref.read(aiRequestQueueProvider);
    queue.updateTpmLimit(settings.tpmLimit);

    try {
      final out = await queue.schedule<String>(
        estimatedTokens: estimateTokens(
          '$_summarySystemInstruction\n$userPrompt',
        ),
        priority: priority,
        onStart: () {
          if (requestId != _summaryRequestId) return;
          state = state.copyWith(summaryStatus: ArticleAiTaskStatus.running);
        },
        task: () async {
          final client = ref.read(aiServiceClientProvider);
          return client.generateText(
            service: service,
            apiKey: apiKey,
            systemInstruction: _summarySystemInstruction,
            userPrompt: userPrompt,
            maxOutputTokens: 800,
          );
        },
      );
      if (requestId != _summaryRequestId) return;
      final text = out.trim();
      state = state.copyWith(
        summaryText: text,
        summaryStatus: ArticleAiTaskStatus.ready,
        summaryError: null,
        summaryOutdated: false,
      );
      unawaited(
        cacheStore.write(
          AiContentCacheEntry(
            key: cacheKey,
            contentHash: contentHash,
            promptHash: promptHash,
            data: text,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e, st) {
      if (requestId != _summaryRequestId) return;
      _logAiTaskFailure(
        operation: 'summarizeArticle',
        error: e,
        stackTrace: st,
        article: article,
        service: service,
        targetLanguageTag: _targetLanguageTag,
        priority: priority,
      );
      state = state.copyWith(
        summaryStatus: ArticleAiTaskStatus.error,
        summaryError: e.toString(),
      );
    }
  }

  Future<void> ensureTranslation({
    required ArticleTranslationMode mode,
    bool force = false,
    AiRequestPriority priority = AiRequestPriority.foreground,
  }) async {
    final requestId = ++_translationRequestId;
    final article = _article;
    final settings = _translationSettings;
    final l10n = _l10n;
    if (article == null || settings == null || l10n == null) return;
    final contentHash = _contentHash.trim();
    if (contentHash.isEmpty) return;
    if (_activeHtml.trim().isEmpty) return;

    final provider = settings.translationProvider;
    final providerKind = provider.kind.name;
    final providerServiceId = provider.kind == TranslationProviderKind.aiService
        ? provider.aiServiceId
        : null;
    final cacheKey = AiContentCacheKey.translation(
      accountId: ref.read(activeAccountProvider).id,
      articleId: article.id,
      targetLanguageTag: _targetLanguageTag,
      translationMode: mode,
      translationProviderKind: providerKind,
      translationProviderServiceId: providerServiceId,
    );
    final cacheStore = ref.read(aiContentCacheStoreProvider);

    final promptTemplate = provider.kind == TranslationProviderKind.aiService
        ? ((settings.aiTranslationPrompt ?? '').trim().isNotEmpty
              ? settings.aiTranslationPrompt!.trim()
              : l10n.defaultAiTranslationPromptTemplate(
                  PromptTemplate.token(PromptTemplate.varLanguage),
                  PromptTemplate.token(PromptTemplate.varTitle),
                  PromptTemplate.token(PromptTemplate.varContent),
                ))
        : null;
    final promptHash = promptTemplate == null
        ? null
        : _promptContractHash(
            version: _translationPromptContractVersion,
            systemInstruction: _translationSystemInstruction,
            userTemplate: promptTemplate,
          );

    final cached = await cacheStore.read(cacheKey);
    if (requestId != _translationRequestId) return;
    if (cached != null && cached.contentHash == contentHash) {
      final cachedHtml = cached.data.trim();
      if (cachedHtml.isNotEmpty) {
        final outdated = promptHash != null && cached.promptHash != promptHash;
        state = state.copyWith(
          translationHtml: cachedHtml,
          translationMode: mode,
          translationStatus: ArticleAiTaskStatus.ready,
          translationError: null,
          translationOutdated: outdated,
        );
        _refreshLanguageBanner();
        if (!force && !outdated) return;
        if (!force && outdated) return;
      }
    } else if (cached != null && cached.contentHash != contentHash) {
      unawaited(cacheStore.delete(cacheKey));
    }

    state = state.copyWith(
      translationHtml: null,
      translationMode: mode,
      translationStatus: ArticleAiTaskStatus.queued,
      translationError: null,
      translationOutdated: false,
    );
    _refreshLanguageBanner();

    try {
      await _translateHtmlProgressively(
        requestId: requestId,
        article: article,
        settings: settings,
        provider: provider,
        mode: mode,
        targetLanguageTag: _targetLanguageTag,
        promptTemplate: promptTemplate,
        promptHash: promptHash,
        cacheKey: cacheKey,
        contentHash: contentHash,
        cacheStore: cacheStore,
        priority: priority,
      );
    } catch (e, st) {
      if (requestId != _translationRequestId) return;
      _logAiTaskFailure(
        operation: 'translateArticle',
        error: e,
        stackTrace: st,
        article: article,
        settings: settings,
        provider: provider,
        mode: mode,
        targetLanguageTag: _targetLanguageTag,
        priority: priority,
      );
      state = state.copyWith(
        translationStatus: ArticleAiTaskStatus.error,
        translationError: e.toString(),
      );
      _refreshLanguageBanner();
    }
  }

  void _logAiTaskFailure({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
    required Article article,
    TranslationAiSettings? settings,
    AiServiceConfig? service,
    TranslationProviderSelection? provider,
    ArticleTranslationMode? mode,
    required String targetLanguageTag,
    required AiRequestPriority priority,
  }) {
    final providerKind = provider?.kind.name ?? 'aiService';
    final providerServiceId =
        provider?.kind == TranslationProviderKind.aiService
        ? provider?.aiServiceId
        : service?.id;
    final resolvedService =
        service ??
        settings?.aiServices
            .where((s) => s.id == providerServiceId)
            .firstOrNull;
    AppLogger.w(
      'Article AI task failed',
      tag: 'ai',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'articleId': article.id,
        'providerKind': providerKind,
        'apiType': resolvedService?.apiType.name,
        'serviceId': providerServiceId,
        'model': resolvedService?.defaultModel,
        'targetLanguageTag': targetLanguageTag,
        'translationMode': mode?.name,
        'priority': priority.name,
      },
    );
  }

  Future<void> _translateHtmlProgressively({
    required int requestId,
    required Article article,
    required TranslationAiSettings settings,
    required TranslationProviderSelection provider,
    required ArticleTranslationMode mode,
    required String targetLanguageTag,
    required String? promptTemplate,
    required String? promptHash,
    required AiContentCacheKey cacheKey,
    required String contentHash,
    required AiContentCacheStore cacheStore,
    required AiRequestPriority priority,
  }) async {
    final doc = html_parser.parse(_activeHtml);
    final body = doc.body;
    if (body == null) return;

    final elements = _translationTargets(body);
    if (elements.isEmpty) return;

    final l10n = _l10n!;
    final languageName = localizedLanguageNameForTag(
      _uiLocale,
      targetLanguageTag,
    );
    final title = (article.title ?? '').trim().isNotEmpty
        ? article.title!.trim()
        : article.link;

    final secrets = ref.read(translationAiSecretStoreProvider);
    final translationService = ref.read(translationServiceProvider);
    final aiClient = ref.read(aiServiceClientProvider);
    final queue = ref.read(aiRequestQueueProvider);
    queue.updateTpmLimit(settings.tpmLimit);

    AiServiceConfig? aiService;
    String? aiApiKey;
    if (provider.kind == TranslationProviderKind.aiService) {
      final id = (provider.aiServiceId ?? '').trim();
      if (id.isEmpty) throw StateError(l10n.aiNotConfigured);
      aiService = settings.aiServices.where((s) => s.id == id).firstOrNull;
      if (aiService == null || !aiService.enabled) {
        throw StateError(l10n.aiNotConfigured);
      }
      aiApiKey = await secrets.getAiServiceApiKey(id);
      if (requestId != _translationRequestId) return;
      if (aiApiKey == null || aiApiKey.trim().isEmpty) {
        throw StateError(l10n.aiNotConfigured);
      }
    }

    var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    for (final el in elements) {
      if (requestId != _translationRequestId) return;
      if (el.attributes.containsKey('data-fleur-translation')) continue;
      final src = el.text.trim();
      if (src.isEmpty) continue;
      if (src.length < 2) continue;

      String out;
      if (provider.kind == TranslationProviderKind.aiService) {
        final template = promptTemplate;
        if (template == null) throw StateError(l10n.aiNotConfigured);
        final userPrompt = PromptTemplate.render(
          template,
          variables: <String, String>{
            PromptTemplate.varContent: src,
            PromptTemplate.varLanguage: languageName,
            PromptTemplate.varTitle: title,
          },
        );
        out = await queue.schedule<String>(
          estimatedTokens: estimateTokens(
            '$_translationSystemInstruction\n$userPrompt',
          ),
          priority: priority,
          onStart: () {
            if (requestId != _translationRequestId) return;
            if (state.translationStatus != ArticleAiTaskStatus.running) {
              state = state.copyWith(
                translationStatus: ArticleAiTaskStatus.running,
              );
            }
          },
          task: () => aiClient.generateText(
            service: aiService!,
            apiKey: aiApiKey!,
            systemInstruction: _translationSystemInstruction,
            userPrompt: userPrompt,
            maxOutputTokens: 800,
          ),
        );
        if (requestId != _translationRequestId) return;
      } else {
        out = await queue.schedule<String>(
          estimatedTokens: estimateTokens(src),
          priority: priority,
          onStart: () {
            if (requestId != _translationRequestId) return;
            if (state.translationStatus != ArticleAiTaskStatus.running) {
              state = state.copyWith(
                translationStatus: ArticleAiTaskStatus.running,
              );
            }
          },
          task: () => translationService.translateText(
            provider: provider,
            settings: settings,
            secrets: secrets,
            text: src,
            targetLanguageTag: targetLanguageTag,
          ),
        );
        if (requestId != _translationRequestId) return;
      }

      final translated = out.trim();
      if (translated.isEmpty) continue;

      if (mode == ArticleTranslationMode.traditional) {
        el.text = translated;
      } else {
        final tag = el.localName?.toLowerCase() ?? '';
        if (_appendTranslationInside(tag)) {
          final node = dom.Element.tag('div')
            ..attributes['data-fleur-translation'] = '1'
            ..attributes['style'] = 'opacity:0.75;font-style:italic;'
            ..text = translated;
          el.append(node);
        } else {
          final node = dom.Element.tag('p')
            ..attributes['data-fleur-translation'] = '1'
            ..attributes['style'] = 'opacity:0.75;font-style:italic;'
            ..text = translated;
          final parent = el.parent;
          if (parent != null) {
            final idx = parent.nodes.indexOf(el);
            if (idx >= 0) {
              parent.nodes.insert(idx + 1, node);
            } else {
              parent.append(node);
            }
          }
        }
      }

      final now = DateTime.now();
      if (now.difference(lastUiUpdate) >= const Duration(milliseconds: 350)) {
        if (requestId != _translationRequestId) return;
        lastUiUpdate = now;
        final html = body.innerHtml.trim();
        state = state.copyWith(translationHtml: html);
      }
    }

    final finalHtml = body.innerHtml.trim();
    if (requestId != _translationRequestId) return;
    state = state.copyWith(
      translationHtml: finalHtml,
      translationMode: mode,
      translationStatus: ArticleAiTaskStatus.ready,
      translationError: null,
      translationOutdated: false,
    );
    _refreshLanguageBanner();

    final entry = AiContentCacheEntry(
      key: cacheKey,
      contentHash: contentHash,
      promptHash: promptHash,
      data: finalHtml,
      updatedAt: DateTime.now(),
    );
    unawaited(cacheStore.write(entry));
  }

  void clearTranslation() {
    _translationRequestId++;
    state = state.copyWith(
      translationHtml: null,
      translationMode: null,
      translationStatus: ArticleAiTaskStatus.idle,
      translationError: null,
      translationOutdated: false,
    );
    _refreshLanguageBanner();
  }

  static String _extractPlainText(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return '';
    final doc = html_parser.parse(trimmed);
    for (final e in doc.querySelectorAll('script,style,noscript')) {
      e.remove();
    }
    final text = (doc.body?.text ?? '')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  static String _promptContractHash({
    required String version,
    required String systemInstruction,
    required String userTemplate,
  }) {
    return PromptTemplate.hash(
      [
        version.trim(),
        systemInstruction.trim(),
        userTemplate.trim(),
      ].join('\n\n'),
    );
  }

  static String _sampleSummaryContent(String content) {
    const maxChars = 40000;
    const separator = '\n\n[...]\n\n';
    final normalized = content.trim();
    if (normalized.length <= maxChars) return normalized;

    final available = maxChars - separator.length;
    final headChars = (available * 0.6).round();
    final tailChars = available - headChars;
    final head = normalized.substring(0, headChars).trimRight();
    final tail = normalized.substring(normalized.length - tailChars).trimLeft();
    return '$head$separator$tail';
  }

  static List<dom.Element> _translationTargets(dom.Element body) {
    const selector =
        'p,li,h1,h2,h3,h4,h5,h6,blockquote,figcaption,caption,td,th';
    const nestedBlockSelector =
        'p,li,h1,h2,h3,h4,h5,h6,blockquote,figcaption,caption,td,th';
    final out = <dom.Element>[];

    for (final el in body.querySelectorAll(selector)) {
      final tag = el.localName?.toLowerCase() ?? '';
      if (tag.isEmpty) continue;
      if (_isInsideCodeBlock(el)) continue;
      if (el.attributes.containsKey('data-fleur-translation')) continue;
      if (_isContainerTag(tag) &&
          el.querySelector(nestedBlockSelector) != null) {
        continue;
      }
      out.add(el);
    }
    return out;
  }

  static bool _isInsideCodeBlock(dom.Element element) {
    for (
      dom.Node? current = element.parent;
      current != null;
      current = current.parent
    ) {
      if (current is! dom.Element) continue;
      final tag = current.localName?.toLowerCase() ?? '';
      if (tag == 'pre' || tag == 'code') return true;
    }
    return false;
  }

  static bool _isContainerTag(String tag) {
    return tag == 'blockquote' ||
        tag == 'figcaption' ||
        tag == 'caption' ||
        tag == 'td' ||
        tag == 'th';
  }

  static bool _appendTranslationInside(String tag) {
    return tag == 'li' || _isContainerTag(tag);
  }
}
