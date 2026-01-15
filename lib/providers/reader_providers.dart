import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';
import 'service_providers.dart';

class FullTextController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> fetch(int articleId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(articleRepositoryProvider);
      final article = await repo.getById(articleId);
      if (article == null) return;
      if (article.fullContentHtml != null && article.fullContentHtml!.trim().isNotEmpty) {
        return;
      }
      final extracted = await ref.read(articleExtractorProvider).extract(article.link);
      await repo.setFullContent(articleId, extracted.contentHtml);
    });
  }
}

final fullTextControllerProvider =
    AutoDisposeAsyncNotifierProvider<FullTextController, void>(FullTextController.new);

