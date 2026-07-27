import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/background_sync_providers.dart';
import 'package:fleur/providers/outbox_flush_providers.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/services/actions/article_action_service.dart';
import 'package:fleur/services/ai/ai_request_queue.dart';
import 'package:fleur/services/ai/ai_service_client.dart';
import 'package:fleur/services/cache/ai_content_cache_store.dart';
import 'package:fleur/services/cache/image_meta_store.dart';
import 'package:fleur/services/notifications/notification_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/services/settings/reader_settings_store.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/settings/reader_progress_store.dart';
import 'package:fleur/services/settings/translation_ai_secret_store.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings_store.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/services/translation/translation_service.dart';
import 'package:fleur/theme/app_theme.dart';

Account buildTestAccount({
  String id = 'account-test',
  AccountType type = AccountType.local,
  String name = 'Test Account',
  String? baseUrl,
  String? profileId,
  String? dbName,
  bool isPrimary = false,
  bool databaseInitialized = true,
  bool deletionPending = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Account(
    id: id,
    type: type,
    name: name,
    baseUrl: baseUrl,
    profileId: profileId,
    dbName: dbName,
    isPrimary: isPrimary,
    databaseInitialized: databaseInitialized,
    deletionPending: deletionPending,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpLocalizedTestApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const <Override>[],
  Locale locale = const Locale('en'),
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
}

class FakeAppSettingsStore implements AppSettingsStore {
  FakeAppSettingsStore(this.settings);

  AppSettings settings;
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings next) async {
    saveCount++;
    settings = next;
  }
}

class FakeReaderSettingsStore implements ReaderSettingsStore {
  FakeReaderSettingsStore(this.settings);

  ReaderSettings settings;

  @override
  Future<ReaderSettings> load() async => settings;

  @override
  Future<void> save(ReaderSettings next) async {
    settings = next;
  }
}

class FakeTranslationAiSettingsStore implements TranslationAiSettingsStore {
  FakeTranslationAiSettingsStore(this.settings);

  TranslationAiSettings settings;
  int saveCount = 0;

  @override
  Future<TranslationAiSettings> load() async => settings;

  @override
  Future<void> save(TranslationAiSettings next) async {
    saveCount++;
    settings = next;
  }
}

class FakeTranslationAiSecretStore implements TranslationAiSecretStore {
  FakeTranslationAiSecretStore({
    this.throwOnSet = false,
    this.throwOnDelete = false,
    this.deepLApiKey,
    Map<String, String>? aiServiceApiKeys,
    ({String appId, String appKey})? baiduCredentials,
  }) : _aiServiceApiKeys = <String, String>{
         if (aiServiceApiKeys != null) ...aiServiceApiKeys,
       },
       _baiduCredentials = baiduCredentials;

  bool throwOnSet;
  bool throwOnDelete;
  String? deepLApiKey;

  int setCalls = 0;
  int deleteCalls = 0;

  final Map<String, String> _aiServiceApiKeys;
  ({String appId, String appKey})? _baiduCredentials;

  @override
  Future<void> setBaiduCredentials({
    required String appId,
    required String appKey,
  }) async {
    _baiduCredentials = (appId: appId.trim(), appKey: appKey);
  }

  @override
  Future<({String appId, String appKey})?> getBaiduCredentials() async {
    return _baiduCredentials;
  }

  @override
  Future<void> deleteBaiduCredentials() async {
    _baiduCredentials = null;
  }

  @override
  Future<void> setDeepLApiKey(String apiKey) async {
    setCalls++;
    if (throwOnSet) throw Exception('secure storage write failed');
    deepLApiKey = apiKey.trim();
  }

  @override
  Future<String?> getDeepLApiKey() async {
    final trimmed = (deepLApiKey ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> deleteDeepLApiKey() async {
    deleteCalls++;
    if (throwOnDelete) throw Exception('secure storage delete failed');
    deepLApiKey = null;
  }

  @override
  Future<void> setAiServiceApiKey(String serviceId, String apiKey) async {
    setCalls++;
    if (throwOnSet) throw Exception('secure storage write failed');
    _aiServiceApiKeys[serviceId] = apiKey.trim();
  }

  @override
  Future<String?> getAiServiceApiKey(String serviceId) async {
    final v = _aiServiceApiKeys[serviceId];
    final trimmed = (v ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> deleteAiServiceApiKey(String serviceId) async {
    deleteCalls++;
    if (throwOnDelete) throw Exception('secure storage delete failed');
    _aiServiceApiKeys.remove(serviceId);
  }
}

class InMemoryAiContentCacheStore extends AiContentCacheStore {
  final Map<String, AiContentCacheEntry> _entries =
      <String, AiContentCacheEntry>{};

  String _key(AiContentCacheKey key) => jsonEncode(key.toJson());

  @override
  Future<AiContentCacheEntry?> read(AiContentCacheKey key) async {
    return _entries[_key(key)];
  }

  @override
  Future<void> write(AiContentCacheEntry entry) async {
    _entries[_key(entry.key)] = entry;
  }

  @override
  Future<void> delete(AiContentCacheKey key) async {
    _entries.remove(_key(key));
  }
}

class ImmediateAiRequestQueue extends AiRequestQueue {
  ImmediateAiRequestQueue() : super(maxConcurrent: 8);

  int lastTpmLimit = 0;

  @override
  void updateTpmLimit(int limit) {
    lastTpmLimit = limit;
  }

  @override
  Future<T> schedule<T>({
    required int estimatedTokens,
    required AiRequestPriority priority,
    required Future<T> Function() task,
    void Function()? onStart,
  }) async {
    onStart?.call();
    return task();
  }
}

class FakeAiServiceClient extends AiServiceClient {
  FakeAiServiceClient({this.onGenerateText}) : super(dio: Dio());

  Future<String> Function({
    required AiServiceConfig service,
    required String apiKey,
    required String? systemInstruction,
    required String userPrompt,
    required int maxOutputTokens,
  })?
  onGenerateText;

  final List<String> prompts = <String>[];
  final List<String?> systemInstructions = <String?>[];
  final List<String> userPrompts = <String>[];

  @override
  Future<String> generateText({
    required AiServiceConfig service,
    required String apiKey,
    String? systemInstruction,
    required String userPrompt,
    int maxOutputTokens = 800,
  }) async {
    prompts.add(userPrompt);
    systemInstructions.add(systemInstruction);
    userPrompts.add(userPrompt);
    final callback = onGenerateText;
    if (callback != null) {
      return callback(
        service: service,
        apiKey: apiKey,
        systemInstruction: systemInstruction,
        userPrompt: userPrompt,
        maxOutputTokens: maxOutputTokens,
      );
    }
    return 'stub-output';
  }
}

class FakeTranslationService extends TranslationService {
  FakeTranslationService({this.onTranslateText}) : super(dio: Dio());

  Future<String> Function({
    required TranslationProviderSelection provider,
    required TranslationAiSettings settings,
    required TranslationAiSecretStore secrets,
    required String text,
    required String targetLanguageTag,
  })?
  onTranslateText;

  final List<String> translatedInputs = <String>[];

  @override
  Future<String> translateText({
    required TranslationProviderSelection provider,
    required TranslationAiSettings settings,
    required TranslationAiSecretStore secrets,
    required String text,
    required String targetLanguageTag,
  }) async {
    translatedInputs.add(text);
    final callback = onTranslateText;
    if (callback != null) {
      return callback(
        provider: provider,
        settings: settings,
        secrets: secrets,
        text: text,
        targetLanguageTag: targetLanguageTag,
      );
    }
    return '$text ($targetLanguageTag)';
  }
}

class RecordingArticleActionService implements ArticleActionService {
  final List<({int articleId, bool isRead})> markReadCalls =
      <({int articleId, bool isRead})>[];
  final List<int> toggleStarCalls = <int>[];
  final List<int> toggleReadLaterCalls = <int>[];
  final List<
    ({
      int? feedId,
      int? categoryId,
      bool starredOnly,
      bool readLaterOnly,
      int? tagId,
    })
  >
  markAllReadCalls =
      <
        ({
          int? feedId,
          int? categoryId,
          bool starredOnly,
          bool readLaterOnly,
          int? tagId,
        })
      >[];

  @override
  Future<void> markRead(int articleId, bool isRead) async {
    markReadCalls.add((articleId: articleId, isRead: isRead));
  }

  @override
  Future<void> toggleStar(int articleId) async {
    toggleStarCalls.add(articleId);
  }

  @override
  Future<void> toggleReadLater(int articleId) async {
    toggleReadLaterCalls.add(articleId);
  }

  @override
  Future<void> markAllRead({
    int? feedId,
    int? categoryId,
    bool starredOnly = false,
    bool readLaterOnly = false,
    int? tagId,
  }) async {
    markAllReadCalls.add((
      feedId: feedId,
      categoryId: categoryId,
      starredOnly: starredOnly,
      readLaterOnly: readLaterOnly,
      tagId: tagId,
    ));
  }
}

class InMemoryReaderProgressStore extends ReaderProgressStore {
  final Map<String, ReaderProgress> _entries = <String, ReaderProgress>{};

  List<ReaderProgress> get entries => _entries.values.toList(growable: false);

  String _key(int articleId, String contentHash) => '$articleId:$contentHash';

  @override
  Future<ReaderProgress?> getProgress({
    required int articleId,
    required String contentHash,
  }) async {
    return _entries[_key(articleId, contentHash)];
  }

  @override
  Future<void> saveProgress(ReaderProgress progress) async {
    _entries[_key(progress.articleId, progress.contentHash)] = progress;
  }
}

class InMemoryImageMetaStore extends ImageMetaStore {
  final Map<String, ImageMeta> _entries = <String, ImageMeta>{};

  @override
  ImageMeta? peek(String url) => _entries[url];

  @override
  Future<ImageMeta?> get(String url) async => _entries[url];

  @override
  Future<Map<String, ImageMeta>> getMany(Iterable<String> urls) async {
    final out = <String, ImageMeta>{};
    for (final url in urls) {
      final meta = _entries[url];
      if (meta != null) out[url] = meta;
    }
    return out;
  }

  @override
  Future<void> saveMany(Map<String, ImageMeta> entries) async {
    _entries.addAll(entries);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

class FakeNotificationService extends NotificationService {
  int bindTapHandlerCalls = 0;
  int initCalls = 0;
  int actualInitCalls = 0;
  int permissionCalls = 0;
  int actualPermissionCalls = 0;
  bool throwOnInit = false;
  bool throwOnRequestPermissions = false;

  bool _initialized = false;
  bool _permissionRequested = false;
  void Function(NotificationTap tap)? _handler;

  @override
  void setOnNotificationTap(void Function(NotificationTap tap) handler) {
    bindTapHandlerCalls++;
    _handler = handler;
  }

  @override
  Future<void> init() async {
    initCalls++;
    if (throwOnInit) {
      throw Exception('fake notification init failed');
    }
    if (_initialized) return;
    _initialized = true;
    actualInitCalls++;
  }

  @override
  Future<void> requestPermissions() async {
    permissionCalls++;
    if (throwOnRequestPermissions) {
      throw Exception('fake notification permission failed');
    }
    if (_permissionRequested) return;
    _permissionRequested = true;
    actualPermissionCalls++;
  }

  void dispatch(NotificationTap tap) {
    _handler?.call(tap);
  }
}

class FakeOutboxStore extends OutboxStore {
  final Map<String, List<OutboxAction>> entries =
      <String, List<OutboxAction>>{};

  @override
  Future<List<OutboxAction>> load(String accountId) async {
    return List<OutboxAction>.of(entries[accountId] ?? const <OutboxAction>[]);
  }

  @override
  Future<void> save(String accountId, List<OutboxAction> actions) async {
    entries[accountId] = List<OutboxAction>.of(actions);
  }

  @override
  Future<void> enqueue(String accountId, OutboxAction action) async {
    final next = List<OutboxAction>.of(
      entries[accountId] ?? const <OutboxAction>[],
    );
    next.add(action);
    entries[accountId] = next;
  }

  @override
  Future<void> remove(String accountId, OutboxAction action) async {
    final next = List<OutboxAction>.of(
      entries[accountId] ?? const <OutboxAction>[],
    );
    final index = next.indexWhere(
      (candidate) =>
          candidate.type == action.type &&
          candidate.remoteEntryKey == action.remoteEntryKey &&
          candidate.remoteEntryId == action.remoteEntryId &&
          candidate.feedUrl == action.feedUrl &&
          candidate.categoryTitle == action.categoryTitle &&
          candidate.streamId == action.streamId &&
          candidate.value == action.value &&
          candidate.createdAt == action.createdAt,
    );
    if (index >= 0) next.removeAt(index);
    entries[accountId] = next;
  }
}

class FakeSyncService implements SyncServiceBase, OutboxFlushCapable {
  FakeSyncService({
    this.flushResult = true,
    BatchRefreshResult? refreshResult,
    this.onFlush,
    this.onRefresh,
  }) : refreshResult =
           refreshResult ?? const BatchRefreshResult(<FeedRefreshResult>[]);

  bool flushResult;
  BatchRefreshResult refreshResult;
  Future<bool> Function()? onFlush;
  Future<BatchRefreshResult> Function(List<int> feedIds)? onRefresh;
  int flushCalls = 0;
  final List<List<int>> refreshCalls = <List<int>>[];

  @override
  Future<int> offlineCacheFeed(int feedId) async => 0;

  @override
  Future<FeedRefreshResult> refreshFeedSafe(
    int feedId, {
    int maxAttempts = 2,
    AppSettings? appSettings,
    bool notify = true,
  }) async {
    refreshCalls.add(<int>[feedId]);
    return refreshResult.results.isEmpty
        ? FeedRefreshResult(feedId: feedId, incomingCount: 0, newCount: 0)
        : refreshResult.results.first;
  }

  @override
  Future<BatchRefreshResult> refreshFeedsSafe(
    Iterable<int> feedIds, {
    int maxConcurrent = 2,
    int maxAttemptsPerFeed = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  }) async {
    final ids = feedIds.toList(growable: false);
    refreshCalls.add(ids);
    onProgress?.call(ids.length, ids.length);
    final callback = onRefresh;
    if (callback != null) {
      return callback(ids);
    }
    return refreshResult;
  }

  @override
  Future<BatchRefreshResult> syncAccountSafe({
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    Iterable<int>? feedIds,
  }) async {
    final ids = feedIds?.toList(growable: false) ?? const <int>[];
    refreshCalls.add(ids);
    onProgress?.call(ids.length, ids.length);
    final callback = onRefresh;
    if (callback != null) {
      return callback(ids);
    }
    return refreshResult;
  }

  @override
  Future<bool> flushOutboxSafe() async {
    flushCalls++;
    final callback = onFlush;
    if (callback != null) {
      return callback();
    }
    return flushResult;
  }
}

class FakeBackgroundSyncScheduler implements BackgroundSyncScheduler {
  final List<Duration> scheduledFrequencies = <Duration>[];
  int cancelCalls = 0;

  @override
  Future<void> schedulePeriodic({required Duration frequency}) async {
    scheduledFrequencies.add(frequency);
  }

  @override
  Future<void> cancelPeriodic() async {
    cancelCalls++;
  }
}

class FakeOutboxFlushTimerHandle implements OutboxFlushTimerHandle {
  FakeOutboxFlushTimerHandle(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool canceled = false;

  @override
  void cancel() {
    canceled = true;
  }

  void fire() {
    if (canceled) return;
    callback();
  }
}

class FakeOutboxFlushTimerFactory {
  final List<FakeOutboxFlushTimerHandle> handles =
      <FakeOutboxFlushTimerHandle>[];

  OutboxFlushTimerHandle call(Duration delay, void Function() callback) {
    final handle = FakeOutboxFlushTimerHandle(delay, callback);
    handles.add(handle);
    return handle;
  }

  FakeOutboxFlushTimerHandle get lastHandle => handles.last;
}
