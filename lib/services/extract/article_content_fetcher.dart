import '../../models/article.dart';
import '../accounts/account.dart';
import '../settings/app_settings.dart';
import '../sync/backend_content_capabilities.dart';
import '../sync/remote_client_factory.dart';
import 'article_extractor.dart';

class ArticleContentFetcher {
  const ArticleContentFetcher({
    required Account account,
    required BackendContentCapabilities contentCapabilities,
    required ArticleExtractor extractor,
    required RemoteClientFactory remoteClients,
  }) : _account = account,
       _contentCapabilities = contentCapabilities,
       _extractor = extractor,
       _remoteClients = remoteClients;

  final Account _account;
  final BackendContentCapabilities _contentCapabilities;
  final ArticleExtractor _extractor;
  final RemoteClientFactory _remoteClients;

  Future<ExtractedArticle> fetch(
    Article article, {
    required AppSettings settings,
  }) async {
    if (_contentCapabilities.canFetchArticleContentFromServer &&
        settings.minifluxWebFetchMode ==
            MinifluxWebFetchMode.serverFetchContent) {
      final remoteId = int.tryParse((article.remoteId ?? '').trim());
      if (remoteId == null) {
        throw StateError('Miniflux entry id is missing');
      }
      final client = await _remoteClients.miniflux(_account);
      final contentHtml = await client.fetchEntryContent(remoteId);
      if (contentHtml.trim().isEmpty) {
        throw StateError('Miniflux fetch-content returned empty content');
      }
      return ExtractedArticle(
        title: article.title?.trim() ?? '',
        contentHtml: contentHtml,
      );
    }

    return _extractor.extract(
      article.link,
      userAgent: settings.webUserAgent,
      expectedTitle: article.title,
    );
  }
}
