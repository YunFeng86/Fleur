import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/article_repository.dart';
import '../repositories/feed_repository.dart';
import 'core_providers.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(isarProvider));
});

final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return ArticleRepository(ref.watch(isarProvider));
});

