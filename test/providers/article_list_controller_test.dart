import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/services/settings/app_settings.dart';

import '../test_utils/critical_workflow_test_support.dart';
import '../test_utils/isar_test_utils.dart';

class _ControlledArticleRepository extends ArticleRepository {
  _ControlledArticleRepository(super.isar);

  final List<Completer<List<int>>> idRequests = [];
  final List<Completer<List<Article>>> pageRequests = [];
  List<Article> page = const [];
  bool blockPageRequests = false;

  @override
  Stream<void> watchQueryChanges(ArticleQuery query) => const Stream.empty();

  @override
  Future<List<int>> fetchPageIds(
    ArticleQuery query, {
    required int offset,
    required int limit,
  }) {
    final request = Completer<List<int>>();
    idRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Article>> fetchPage(
    ArticleQuery query, {
    required int offset,
    required int limit,
  }) {
    if (blockPageRequests) {
      final request = Completer<List<Article>>();
      pageRequests.add(request);
      return request.future;
    }
    return Future<List<Article>>.value(page);
  }
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_article_list_controller_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'article_list_controller_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    tempDir = null;
    isar = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer({
    bool unreadOnly = false,
    int? selectedArticleId,
    AppSettings? settings,
    ArticleListFilter filter = const ArticleListFilter(),
    ArticleRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar!),
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(settings ?? AppSettings.defaults()),
        ),
        articleListFilterProvider.overrideWith((ref) => filter),
        activeArticleListSelectionProvider.overrideWith(
          (ref) => selectedArticleId,
        ),
        unreadOnlyProvider.overrideWith((ref) => unreadOnly),
        if (repository != null)
          articleRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> seedArticles(int count) async {
    final now = DateTime.utc(2026, 5, 1, 12);
    await isar!.writeTxn(() async {
      final feed = Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Example';
      await isar!.feeds.put(feed);

      final articles = List<Article>.generate(count, (index) {
        final id = index + 1;
        return Article()
          ..id = id
          ..feedId = feed.id
          ..link = 'https://example.com/articles/$id'
          ..title = 'Article $id'
          ..contentHtml = '<p>Article $id</p>'
          ..publishedAt = now.subtract(Duration(minutes: index))
          ..fetchedAt = now
          ..updatedAt = now
          ..isRead = false;
      });
      await isar!.articles.putAll(articles);
    });
  }

  Future<void> seedSearchArticle() async {
    final now = DateTime.utc(2026, 5, 1, 12);
    await isar!.writeTxn(() async {
      final feed = Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Example';
      await isar!.feeds.put(feed);

      final article = Article()
        ..id = 1
        ..feedId = feed.id
        ..link = 'https://example.com/articles/1'
        ..title = 'Title only'
        ..contentHtml = '<p>needle only in content</p>'
        ..publishedAt = now
        ..fetchedAt = now
        ..updatedAt = now
        ..isRead = false;
      await isar!.articles.put(article);
    });
  }

  List<int> articleIds(ArticleListState state) {
    return state.items.map((article) => article.id).toList(growable: false);
  }

  void keepArticleListAlive(ProviderContainer container) {
    final subscription = container.listen<AsyncValue<ArticleListState>>(
      articleListControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
  }

  test('refresh keeps the loaded window after a read-status update', () async {
    await seedArticles(120);
    final container = buildContainer();
    keepArticleListAlive(container);
    await container.read(appSettingsProvider.future);

    var state = await container.read(articleListControllerProvider.future);
    expect(articleIds(state), orderedEquals(List.generate(50, (i) => i + 1)));

    await container.read(articleListControllerProvider.notifier).loadMore();
    state = container.read(articleListControllerProvider).requireValue;
    expect(articleIds(state), orderedEquals(List.generate(100, (i) => i + 1)));
    expect(state.nextOffset, 100);
    expect(state.hasMore, isTrue);

    await ArticleRepository(isar!).markRead(75, true);
    await container.read(articleListControllerProvider.notifier).refresh();

    state = container.read(articleListControllerProvider).requireValue;
    expect(articleIds(state), orderedEquals(List.generate(100, (i) => i + 1)));
    expect(state.startOffset, 0);
    expect(state.nextOffset, 100);
    expect(state.hasMore, isTrue);
  });

  test('an older refresh cannot overwrite a newer refresh result', () async {
    final repository = _ControlledArticleRepository(isar!);
    final first = Article()
      ..id = 1
      ..title = 'First';
    final second = Article()
      ..id = 2
      ..title = 'Second';
    repository.page = [first];

    final container = buildContainer(repository: repository);
    keepArticleListAlive(container);
    await container.read(appSettingsProvider.future);
    await container.read(articleListControllerProvider.future);

    final notifier = container.read(articleListControllerProvider.notifier);
    final olderRefresh = notifier.refresh();
    await _waitForRequestCount(repository, 1);
    final newerRefresh = notifier.refresh();
    await _waitForRequestCount(repository, 2);

    repository.page = [second];
    repository.idRequests[1].complete([second.id]);
    await newerRefresh;

    repository.idRequests[0].complete([first.id]);
    await olderRefresh;

    final state = container.read(articleListControllerProvider).requireValue;
    expect(articleIds(state), [second.id]);
  });

  test('a failing refresh releases a superseded load-more state', () async {
    final repository = _ControlledArticleRepository(isar!)
      ..page = List<Article>.generate(
        50,
        (index) => Article()
          ..id = index + 1
          ..title = 'Article ${index + 1}',
      );
    final container = buildContainer(repository: repository);
    keepArticleListAlive(container);
    await container.read(appSettingsProvider.future);
    await container.read(articleListControllerProvider.future);

    repository.blockPageRequests = true;
    final notifier = container.read(articleListControllerProvider.notifier);
    final loadMore = notifier.loadMore();
    await _waitForPageRequestCount(repository, 1);
    expect(
      container.read(articleListControllerProvider).requireValue.isLoadingMore,
      isTrue,
    );

    final refresh = notifier.refresh();
    await _waitForRequestCount(repository, 1);
    repository.idRequests.single.completeError(StateError('refresh failed'));
    await expectLater(refresh, throwsStateError);

    expect(
      container.read(articleListControllerProvider).requireValue.isLoadingMore,
      isFalse,
    );

    repository.pageRequests.single.complete(const <Article>[]);
    await loadMore;
  });

  test(
    'refresh keeps unread list window and fills the removed article slot',
    () async {
      await seedArticles(120);
      final container = buildContainer(unreadOnly: true);
      keepArticleListAlive(container);
      await container.read(appSettingsProvider.future);

      await container.read(articleListControllerProvider.future);
      await container.read(articleListControllerProvider.notifier).loadMore();

      await ArticleRepository(isar!).markRead(75, true);
      await container.read(articleListControllerProvider.notifier).refresh();

      final state = container.read(articleListControllerProvider).requireValue;
      final expectedIds = <int>[
        ...List.generate(74, (i) => i + 1),
        ...List.generate(26, (i) => i + 76),
      ];
      expect(articleIds(state), orderedEquals(expectedIds));
      expect(state.items, hasLength(100));
      expect(state.startOffset, 0);
      expect(state.nextOffset, 100);
      expect(state.hasMore, isTrue);
    },
  );

  test(
    'refresh temporarily keeps the selected article in unread lists',
    () async {
      await seedArticles(120);
      final container = buildContainer(unreadOnly: true, selectedArticleId: 75);
      keepArticleListAlive(container);
      await container.read(appSettingsProvider.future);

      await container.read(articleListControllerProvider.future);
      await container.read(articleListControllerProvider.notifier).loadMore();

      await ArticleRepository(isar!).markRead(75, true);
      await container.read(articleListControllerProvider.notifier).refresh();

      var state = container.read(articleListControllerProvider).requireValue;
      expect(
        articleIds(state),
        orderedEquals(List.generate(101, (i) => i + 1)),
      );
      expect(state.items, hasLength(101));
      expect(state.startOffset, 0);
      expect(state.nextOffset, 100);
      expect(state.hasMore, isTrue);

      container.read(activeArticleListSelectionProvider.notifier).state = null;
      await container.read(articleListControllerProvider.notifier).refresh();

      state = container.read(articleListControllerProvider).requireValue;
      final expectedIds = <int>[
        ...List.generate(74, (i) => i + 1),
        ...List.generate(26, (i) => i + 76),
      ];
      expect(articleIds(state), orderedEquals(expectedIds));
      expect(state.items, hasLength(100));
      expect(state.nextOffset, 100);
    },
  );

  test('loadMore caps the retained article window at 500 items', () async {
    await seedArticles(560);
    final container = buildContainer();
    keepArticleListAlive(container);
    await container.read(appSettingsProvider.future);

    var state = await container.read(articleListControllerProvider.future);
    expect(articleIds(state), orderedEquals(List.generate(50, (i) => i + 1)));

    for (var i = 0; i < 10; i++) {
      await container.read(articleListControllerProvider.notifier).loadMore();
    }

    state = container.read(articleListControllerProvider).requireValue;
    expect(state.items, hasLength(500));
    expect(articleIds(state), orderedEquals(List.generate(500, (i) => i + 51)));
    expect(state.startOffset, 50);
    expect(state.nextOffset, 550);
    expect(state.hasMore, isTrue);
  });

  test('refresh keeps short lists without reporting more pages', () async {
    await seedArticles(30);
    final container = buildContainer();
    keepArticleListAlive(container);
    await container.read(appSettingsProvider.future);

    var state = await container.read(articleListControllerProvider.future);
    expect(articleIds(state), orderedEquals(List.generate(30, (i) => i + 1)));
    expect(state.hasMore, isFalse);

    await ArticleRepository(isar!).markRead(10, true);
    await container.read(articleListControllerProvider.notifier).refresh();

    state = container.read(articleListControllerProvider).requireValue;
    expect(articleIds(state), orderedEquals(List.generate(30, (i) => i + 1)));
    expect(state.startOffset, 0);
    expect(state.nextOffset, 30);
    expect(state.hasMore, isFalse);
  });

  test('search content override takes precedence over app settings', () async {
    await seedSearchArticle();

    final titleOnlyContainer = buildContainer(
      settings: AppSettings.defaults().copyWith(searchInContent: true),
      filter: const ArticleListFilter(
        searchQuery: 'needle',
        searchInContentOverride: false,
      ),
    );
    keepArticleListAlive(titleOnlyContainer);
    await titleOnlyContainer.read(appSettingsProvider.future);

    final titleOnlyState = await titleOnlyContainer.read(
      articleListControllerProvider.future,
    );
    expect(articleIds(titleOnlyState), isEmpty);

    final contentContainer = buildContainer(
      settings: AppSettings.defaults().copyWith(searchInContent: false),
      filter: const ArticleListFilter(
        searchQuery: 'needle',
        searchInContentOverride: true,
      ),
    );
    keepArticleListAlive(contentContainer);
    await contentContainer.read(appSettingsProvider.future);

    final contentState = await contentContainer.read(
      articleListControllerProvider.future,
    );
    expect(articleIds(contentState), [1]);
  });
}

Future<void> _waitForRequestCount(
  _ControlledArticleRepository repository,
  int count,
) async {
  while (repository.idRequests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _waitForPageRequestCount(
  _ControlledArticleRepository repository,
  int count,
) async {
  while (repository.pageRequests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}
