import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';
import 'app_settings_providers.dart';
import 'service_providers.dart';
import '../services/settings/reader_progress_store.dart';

final readerProgressStoreProvider = Provider<ReaderProgressStore>((ref) {
  return ReaderProgressStore();
});

class FullTextController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> fetch(int articleId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(articleRepositoryProvider);
      final article = await repo.getById(articleId);
      if (article == null) return;
      if (article.extractedContentHtml != null &&
          article.extractedContentHtml!.trim().isNotEmpty) {
        return;
      }
      final settings = ref.read(appSettingsProvider).valueOrNull;
      final extracted = await ref
          .read(articleExtractorProvider)
          .extract(article.link, userAgent: settings?.webUserAgent);
      if (extracted.contentHtml.trim().isEmpty) {
        await repo.markExtractionFailed(articleId);
        return;
      }
      await repo.setExtractedContent(articleId, extracted.contentHtml);
      await ref
          .read(articleCacheServiceProvider)
          .prefetchImagesFromHtml(
            extracted.contentHtml,
            baseUrl: Uri.tryParse(article.link),
          );
    });
  }
}

final fullTextControllerProvider =
    AutoDisposeAsyncNotifierProvider<FullTextController, void>(
      FullTextController.new,
    );

/// 是否显示提取内容（仅视图层，不持久化）。
final fullTextViewEnabledProvider = StateProvider.autoDispose.family<bool, int>(
  (ref, articleId) => false,
);
