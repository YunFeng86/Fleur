import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository_providers.dart';
import 'app_settings_providers.dart';
import 'service_providers.dart';
import '../services/logging/app_logger.dart';
import '../services/logging/log_context.dart';
import '../services/settings/reader_progress_store.dart';

final readerProgressStoreProvider = Provider<ReaderProgressStore>((ref) {
  return ReaderProgressStore();
});

enum ArticleExtractionErrorType { emptyContent }

class ArticleExtractionException implements Exception {
  const ArticleExtractionException(this.type);

  final ArticleExtractionErrorType type;

  @override
  String toString() => 'ArticleExtractionException($type)';
}

class FullTextController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Fetches full text for the given article.
  ///
  /// Returns `true` if extracted content is available after the call.
  /// Returns `false` when the request fails or the extractor returns empty.
  Future<bool> fetch(int articleId) async {
    var ok = false;
    state = const AsyncLoading();
    try {
      final repo = ref.read(articleRepositoryProvider);
      final article = await repo.getById(articleId);
      if (article == null) {
        state = const AsyncValue.data(null);
        return false;
      }
      if (article.extractedContentHtml != null &&
          article.extractedContentHtml!.trim().isNotEmpty) {
        ok = true;
        state = const AsyncValue.data(null);
        return true;
      }
      final settings = ref.read(appSettingsProvider).valueOrNull;
      final extracted = await ref
          .read(articleExtractorProvider)
          .extract(article.link, userAgent: settings?.webUserAgent);
      if (extracted.contentHtml.trim().isEmpty) {
        await repo.markExtractionFailed(articleId);
        throw const ArticleExtractionException(
          ArticleExtractionErrorType.emptyContent,
        );
      }
      await repo.setExtractedContent(articleId, extracted.contentHtml);
      await ref
          .read(articleCacheServiceProvider)
          .prefetchImagesFromHtml(
            extracted.contentHtml,
            baseUrl: Uri.tryParse(article.link),
          );
      ok = true;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      AppLogger.w(
        'Reader full text fetch failed',
        tag: 'reader',
        error: e,
        stackTrace: st,
        context: _fullTextFailureContext(
          articleId: articleId,
          error: e,
          articleLink: await _articleLinkForLog(articleId),
        ),
      );
      state = AsyncValue.error(e, st);
    }
    return ok;
  }

  Future<String?> _articleLinkForLog(int articleId) async {
    try {
      final article = await ref
          .read(articleRepositoryProvider)
          .getById(articleId);
      return article?.link;
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _fullTextFailureContext({
    required int articleId,
    required Object error,
    String? articleLink,
  }) {
    final extra = <String, Object?>{
      'operation': 'fetchFullText',
      'articleId': articleId,
      'errorType': error.runtimeType,
    };
    final uri = Uri.tryParse((articleLink ?? '').trim());
    if (uri == null) return extra;
    return logContextForUri(uri, method: 'GET', extra: extra);
  }
}

final fullTextControllerProvider =
    AutoDisposeAsyncNotifierProvider<FullTextController, void>(
      FullTextController.new,
      dependencies: [articleRepositoryProvider],
    );
