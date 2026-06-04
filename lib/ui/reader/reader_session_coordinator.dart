part of '../../widgets/reader_view.dart';

String _selectActiveHtmlForArticle(Article article) {
  final extractedHtml = (article.extractedContentHtml ?? '').trim();
  if (extractedHtml.isNotEmpty) {
    return extractedHtml;
  }
  return (article.contentHtml ?? '').trim();
}

final class _ReaderSessionCoordinator {
  _ReaderSessionCoordinator({required _ReaderViewState owner}) : _owner = owner;

  final _ReaderViewState _owner;

  ProviderSubscription<AsyncValue<Article?>>? _articleSub;
  ReaderDocumentKey? _prefetchedDocumentKey;

  WidgetRef get ref => _owner.ref;

  ReaderDocumentRequest buildDocumentRequest({
    required Article article,
    required ReaderSettings settings,
    required ArticleAiState aiState,
  }) {
    final sourceHtml = _selectActiveHtmlForArticle(article);
    final translatedHtml = (aiState.translationHtml ?? '').trim();
    final usesTranslation = translatedHtml.isNotEmpty;
    final rawHtml = usesTranslation ? translatedHtml : sourceHtml;
    return ReaderDocumentRequest(
      articleId: article.id.toString(),
      sourceRevision: _revisionForArticleSource(article, sourceHtml),
      rawHtml: rawHtml,
      baseUrl: article.link,
      displayMode: usesTranslation
          ? ReaderDisplayMode.translation
          : ReaderDisplayMode.source,
      typography: ReaderTypographySettings(
        fontSize: settings.fontSize,
        minimumFontSize: settings.minimumFontSize,
        lineHeight: settings.lineHeight,
        horizontalPadding: settings.horizontalPadding,
      ),
      translationRevision: usesTranslation
          ? _revisionForHtml(translatedHtml, prefix: 'translation')
          : null,
      primaryLanguage: aiState.sourceLanguageTag,
    );
  }

  void maybePrefetchImages({
    required Article article,
    required ReaderDocumentSnapshot snapshot,
  }) {
    if (_prefetchedDocumentKey == snapshot.documentKey) return;
    _prefetchedDocumentKey = snapshot.documentKey;
    if (snapshot.displayHtml.isEmpty) return;
    final maxPrefetch = snapshot.displayHtml.length >= 50000 ? 6 : 24;
    unawaited(
      ref
          .read(articleCacheServiceProvider)
          .prefetchImagesFromHtml(
            snapshot.displayHtml,
            baseUrl: Uri.tryParse(article.link),
            maxImages: maxPrefetch,
            maxConcurrent: 3,
          ),
    );
  }

  void dispose() {
    _articleSub?.close();
    _prefetchedDocumentKey = null;
  }

  void listenTranslationHtml(int articleId) {
    _prefetchedDocumentKey = null;
  }

  void listenArticle(int articleId) {
    _articleSub?.close();
    _prefetchedDocumentKey = null;
    var hasMarkedRead = false;
    _articleSub = ref.listenManual<AsyncValue<Article?>>(
      articleProvider(articleId),
      (prev, next) {
        final article = next.valueOrNull;

        if (!hasMarkedRead && article != null && !article.isRead) {
          final appSettings =
              ref.read(appSettingsProvider).valueOrNull ??
              AppSettings.defaults();
          if (appSettings.autoMarkRead) {
            unawaited(
              ref.read(articleActionServiceProvider).markRead(articleId, true),
            );
            hasMarkedRead = true;
          }
        }
      },
      fireImmediately: true,
    );
  }

  String _revisionForArticleSource(Article article, String sourceHtml) {
    final feedHtml = (article.contentHtml ?? '').trim();
    final storedHash = (article.contentHash ?? '').trim();
    if (storedHash.isNotEmpty && sourceHtml == feedHtml) {
      return 'feed:$storedHash';
    }
    return _revisionForHtml(
      sourceHtml,
      prefix: article.extractedContentHtml?.trim().isNotEmpty == true
          ? 'extracted'
          : 'feed',
      updatedAt: article.updatedAt,
    );
  }

  String _revisionForHtml(
    String html, {
    required String prefix,
    DateTime? updatedAt,
  }) {
    final updated = updatedAt?.microsecondsSinceEpoch ?? 0;
    return '$prefix:$updated:${ContentHash.compute(html)}';
  }
}
