import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/google_reader/google_reader_client.dart';
import 'package:fleur/services/sync/remote_article_action_executor.dart';

void main() {
  test('ClientLogin parses Auth and token uses GoogleLogin header', () async {
    final requests = <_RecordedRequest>[];
    final client = GoogleReaderClient(
      dio: _dio(requests),
      baseUrl: 'https://reader.example.com',
      username: ' user@example.com ',
      password: 'secret',
    );

    expect(await client.token(), 'write-token');

    expect(requests.map((request) => '${request.method} ${request.path}'), [
      'POST /accounts/ClientLogin',
      'GET /reader/api/0/token',
    ]);
    final loginPayload = requests.first.data as Map<String, Object?>;
    expect(loginPayload['Email'], 'user@example.com');
    expect(loginPayload['Passwd'], 'secret');
    expect(
      requests[1].headers['Authorization'],
      'GoogleLogin auth=login-token',
    );
  });

  test('ClientLogin parses Auth from a json string response', () async {
    final requests = <_RecordedRequest>[];
    final client = GoogleReaderClient(
      dio: _dio(requests, clientLoginData: '{"Auth":"json-token"}'),
      baseUrl: 'https://reader.example.com',
      username: 'user@example.com',
      password: 'secret',
    );

    expect(
      await client.clientLogin(
        username: 'user@example.com',
        password: 'secret',
      ),
      'json-token',
    );
  });

  test('subscriptionList keeps reader API base path when supplied', () async {
    final requests = <_RecordedRequest>[];
    final client = GoogleReaderClient(
      dio: _dio(requests),
      baseUrl: 'https://reader.example.com/reader/api/0',
      authToken: ' auth-token ',
    );

    final subscriptions = await client.subscriptionList();

    expect(subscriptions.single['id'], 'feed/https://example.com/feed.xml');
    expect(requests.single.path, '/reader/api/0/subscription/list');
    expect(requests.single.queryParameters['output'], 'json');
    expect(
      requests.single.headers['Authorization'],
      'GoogleLogin auth=auth-token',
    );
  });

  test(
    'item ids, contents, edit-tag and mark-all-read use string ids',
    () async {
      final requests = <_RecordedRequest>[];
      final client = GoogleReaderClient(
        dio: _dio(requests),
        baseUrl: 'https://reader.example.com',
        authToken: 'auth-token',
      );

      final page = await client.streamItemIds(
        streamId: GoogleReaderRemoteArticleActionExecutor.readingListState,
        count: 2,
        continuation: ' next-page ',
        excludeState: GoogleReaderRemoteArticleActionExecutor.readState,
        olderThanSeconds: 123,
      );
      final contents = await client.streamItemsContents([
        'tag:reader.example,2026:item/0001',
        ' 2 ',
      ]);
      await client.editTag(
        itemId: 'tag:reader.example,2026:item/0001',
        add: const [GoogleReaderRemoteArticleActionExecutor.readState],
        remove: const [GoogleReaderRemoteArticleActionExecutor.starredState],
      );
      await client.markAllAsRead(
        streamId: 'feed/https://example.com/feed.xml',
        before: DateTime.utc(2026, 1, 1),
      );

      expect(page.itemIds, ['tag:reader.example,2026:item/0001', '2']);
      expect(page.continuation, 'next-token');
      expect(contents.single['id'], 'tag:reader.example,2026:item/0001');

      final idsRequest = requests[0];
      expect(idsRequest.path, '/reader/api/0/stream/items/ids');
      expect(idsRequest.queryParameters['s'], contains('reading-list'));
      expect(idsRequest.queryParameters['c'], 'next-page');
      expect(idsRequest.queryParameters['xt'], contains('/read'));
      expect(idsRequest.queryParameters['ot'], '123');

      expect(requests[1].path, '/reader/api/0/token');
      final contentsPayload = requests[2].data as Map<String, Object?>;
      expect(contentsPayload['i'], ['tag:reader.example,2026:item/0001', '2']);
      expect(contentsPayload['T'], 'write-token');

      final editPayload = requests[3].data as Map<String, Object?>;
      expect(editPayload['i'], 'tag:reader.example,2026:item/0001');
      expect(editPayload['a'], [
        GoogleReaderRemoteArticleActionExecutor.readState,
      ]);
      expect(editPayload['r'], [
        GoogleReaderRemoteArticleActionExecutor.starredState,
      ]);

      final markAllPayload = requests[4].data as Map<String, Object?>;
      expect(markAllPayload['s'], 'feed/https://example.com/feed.xml');
      expect(markAllPayload['ts'], '1767225600000000');
    },
  );
}

Dio _dio(List<_RecordedRequest> requests, {Object? clientLoginData}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch ((options.method, options.uri.path)) {
          ('POST', '/accounts/ClientLogin') =>
            clientLoginData ?? 'SID=sid\nAuth=login-token\n',
          ('GET', '/reader/api/0/token') => 'write-token',
          ('GET', '/reader/api/0/subscription/list') => {
            'subscriptions': [
              {
                'id': 'feed/https://example.com/feed.xml',
                'title': 'Example Feed',
              },
            ],
          },
          ('GET', '/reader/api/0/stream/items/ids') => {
            'itemRefs': [
              {'id': 'tag:reader.example,2026:item/0001'},
              {'id': '2'},
            ],
            'continuation': ' next-token ',
          },
          ('POST', '/reader/api/0/stream/items/contents') => {
            'items': [
              {'id': 'tag:reader.example,2026:item/0001'},
            ],
          },
          ('POST', '/reader/api/0/edit-tag') => <String, Object?>{},
          ('POST', '/reader/api/0/mark-all-as-read') => <String, Object?>{},
          _ => throw StateError(
            'Unexpected request: ${options.method} ${options.uri}',
          ),
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

class _RecordedRequest {
  _RecordedRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.headers,
    required this.data,
  });

  factory _RecordedRequest.fromOptions(RequestOptions options) {
    return _RecordedRequest(
      method: options.method,
      path: options.uri.path,
      queryParameters: Map<String, String>.from(options.uri.queryParameters),
      headers: Map<String, Object?>.from(options.headers),
      data: options.data,
    );
  }

  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final Map<String, Object?> headers;
  final Object? data;
}
