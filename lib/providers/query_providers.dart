import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../models/feed.dart';
import 'repository_providers.dart';

final feedsProvider = StreamProvider<List<Feed>>((ref) {
  return ref.watch(feedRepositoryProvider).watchAll();
});

final selectedFeedIdProvider = StateProvider<int?>((ref) => null);

final articlesProvider = StreamProvider.family<List<Article>, int?>((ref, feedId) {
  return ref.watch(articleRepositoryProvider).watchLatest(feedId: feedId);
});

final articleProvider = StreamProvider.family<Article?, int>((ref, id) {
  return ref.watch(articleRepositoryProvider).watchById(id);
});

