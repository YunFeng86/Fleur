import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/services/settings/app_settings.dart';

import '../test_utils/critical_workflow_test_support.dart';
import '../test_utils/isar_test_utils.dart';

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

  ProviderContainer buildContainer({bool unreadOnly = false}) {
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar!),
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        unreadOnlyProvider.overrideWith((ref) => unreadOnly),
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
}
