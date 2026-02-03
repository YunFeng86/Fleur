import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/article_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/feed_repository.dart';
import '../repositories/tag_repository.dart';
import 'core_providers.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(isarProvider));
});

final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return ArticleRepository(ref.watch(isarProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(isarProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(isarProvider));
});
