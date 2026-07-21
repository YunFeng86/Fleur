import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/extract/article_content_fetcher.dart';
import 'package:fleur/services/extract/article_extractor.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/remote_client_factory.dart';

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return 'test-token';
  }
}

class _RecordingExtractor extends ArticleExtractor {
  _RecordingExtractor() : super(Dio());

  final urls = <String>[];
  final expectedTitles = <String?>[];

  @override
  Future<ExtractedArticle> extract(
    String url, {
    String? userAgent,
    String? expectedTitle,
  }) async {
    urls.add(url);
    expectedTitles.add(expectedTitle);
    return const ExtractedArticle(
      title: 'Local title',
      contentHtml: '<article><p>Local body</p></article>',
    );
  }
}

void main() {
  test(
    'server mode fetches Miniflux content without local extraction',
    () async {
      final paths = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.uri.path);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                data: const <String, Object?>{
                  'content': '<article><p>Server body</p></article>',
                },
              ),
            );
          },
        ),
      );
      final extractor = _RecordingExtractor();
      final fetcher = ArticleContentFetcher(
        account: _minifluxAccount(),
        extractor: extractor,
        remoteClients: RemoteClientFactory(
          dio: dio,
          credentials: _FakeCredentialStore(),
        ),
      );

      final result = await fetcher.fetch(
        _article(),
        settings: AppSettings.defaults().copyWith(
          minifluxWebFetchMode: MinifluxWebFetchMode.serverFetchContent,
        ),
      );

      expect(paths, ['/v1/entries/42/fetch-content']);
      expect(extractor.urls, isEmpty);
      expect(result.contentHtml, contains('Server body'));
    },
  );

  test(
    'client mode uses local extraction with the known article title',
    () async {
      final extractor = _RecordingExtractor();
      final fetcher = ArticleContentFetcher(
        account: _minifluxAccount(),
        extractor: extractor,
        remoteClients: RemoteClientFactory(
          dio: Dio(),
          credentials: _FakeCredentialStore(),
        ),
      );

      final result = await fetcher.fetch(
        _article(),
        settings: AppSettings.defaults().copyWith(
          minifluxWebFetchMode: MinifluxWebFetchMode.clientReadability,
        ),
      );

      expect(extractor.urls, ['https://example.com/article']);
      expect(extractor.expectedTitles, ['Article title']);
      expect(result.contentHtml, contains('Local body'));
    },
  );

  test('empty server content does not fall back to local extraction', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: const <String, Object?>{'content': ''},
            ),
          );
        },
      ),
    );
    final extractor = _RecordingExtractor();
    final fetcher = ArticleContentFetcher(
      account: _minifluxAccount(),
      extractor: extractor,
      remoteClients: RemoteClientFactory(
        dio: dio,
        credentials: _FakeCredentialStore(),
      ),
    );

    await expectLater(
      fetcher.fetch(
        _article(),
        settings: AppSettings.defaults().copyWith(
          minifluxWebFetchMode: MinifluxWebFetchMode.serverFetchContent,
        ),
      ),
      throwsStateError,
    );
    expect(extractor.urls, isEmpty);
  });
}

Account _minifluxAccount() {
  final now = DateTime(2026);
  return Account(
    id: 'miniflux-test',
    type: AccountType.miniflux,
    name: 'Miniflux',
    baseUrl: 'https://miniflux.example.com',
    createdAt: now,
    updatedAt: now,
  );
}

Article _article() {
  return Article()
    ..remoteId = '42'
    ..link = 'https://example.com/article'
    ..title = 'Article title';
}
