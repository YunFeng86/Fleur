import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/miniflux/miniflux_client.dart';

void main() {
  test('api token wins over basic auth and is trimmed', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests),
      baseUrl: 'https://miniflux.example.com///',
      apiToken: ' token-123 ',
      username: 'user',
      password: 'secret',
    );

    await client.getFeeds();

    final request = requests.single;
    expect(request.path, '/v1/feeds');
    expect(request.headers['X-Auth-Token'], 'token-123');
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('falls back to basic auth when no api token', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests),
      baseUrl: 'https://miniflux.example.com',
      username: ' user ',
      password: 'secret',
    );

    await client.getCategories();

    final expected = 'Basic ${base64Encode(utf8.encode('user:secret'))}';
    expect(requests.single.headers['Authorization'], expected);
    expect(requests.single.headers.containsKey('X-Auth-Token'), isFalse);
  });

  test('getEntries builds paging and repeated status params', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests, data: {'total': 1, 'entries': <Object?>[]}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    final page = await client.getEntries(limit: 50, offset: 100);

    expect(page['total'], 1);
    final request = requests.single;
    expect(request.path, '/v1/entries');
    expect(request.queryParameters['limit'], ['50']);
    expect(request.queryParameters['offset'], ['100']);
    expect(request.queryParameters['status'], ['unread', 'read']);
    expect(request.queryParameters['order'], ['published_at']);
    expect(request.queryParameters['direction'], ['desc']);
  });

  test(
    'getEntries omits offset=0 and returns empty map for bad data',
    () async {
      final requests = <_RecordedRequest>[];
      final client = MinifluxClient(
        dio: _dio(requests, data: 'not-a-map'),
        baseUrl: 'https://miniflux.example.com',
        apiToken: 'token',
      );

      final page = await client.getEntries(limit: 10);

      expect(page, isEmpty);
      expect(requests.single.queryParameters.containsKey('offset'), isFalse);
    },
  );

  test('getFeedEntries scopes to feed path and validates feed id', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests, data: {'entries': <Object?>[]}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await client.getFeedEntries(feedId: 7, limit: 10);
    expect(requests.single.path, '/v1/feeds/7/entries');

    await expectLater(
      client.getFeedEntries(feedId: 0, limit: 10),
      throwsArgumentError,
    );
    expect(requests, hasLength(1));
  });

  test('getFeeds and getCategories tolerate malformed payloads', () async {
    final client = MinifluxClient(
      dio: _dio(
        [],
        data: [
          {'id': 1, 'title': 'Kept'},
          'garbage',
          42,
        ],
      ),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    expect(await client.getFeeds(), [
      {'id': 1, 'title': 'Kept'},
    ]);

    final badShape = MinifluxClient(
      dio: _dio([], data: {'unexpected': true}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );
    expect(await badShape.getFeeds(), isEmpty);
    expect(await badShape.getCategories(), isEmpty);
  });

  test('setEntriesStatus sends batch payload and skips empty ids', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await client.setEntriesStatus(const [], status: 'read');
    expect(requests, isEmpty);

    await client.setEntriesStatus(const [1, 2, 3], status: 'read');
    final request = requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/v1/entries');
    expect(request.data, {
      'entry_ids': [1, 2, 3],
      'status': 'read',
    });
  });

  test('setBookmarkState only toggles when remote state differs', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests, data: {'id': 5, 'starred': true}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await client.setBookmarkState(5, true);
    expect(requests.map((r) => '${r.method} ${r.path}'), ['GET /v1/entries/5']);

    requests.clear();
    await client.setBookmarkState(5, false);
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'GET /v1/entries/5',
      'PUT /v1/entries/5/bookmark',
    ]);
  });

  test('setBookmarkState rejects entries without starred flag', () async {
    final client = MinifluxClient(
      dio: _dio([], data: {'id': 5}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await expectLater(
      client.setBookmarkState(5, true),
      throwsA(isA<StateError>()),
    );
  });

  test('fetchEntryContent returns content or empty string', () async {
    final requests = <_RecordedRequest>[];
    final withContent = MinifluxClient(
      dio: _dio(requests, data: {'content': '<p>Body</p>'}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    expect(await withContent.fetchEntryContent(9), '<p>Body</p>');
    expect(requests.single.path, '/v1/entries/9/fetch-content');
    expect(requests.single.queryParameters['update_content'], ['false']);

    final withoutContent = MinifluxClient(
      dio: _dio([], data: {'something': 'else'}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );
    expect(await withoutContent.fetchEntryContent(9), '');
  });

  test('createFeed validates input then posts payload', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests, data: {'id': 3}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await expectLater(
      client.createFeed(feedUrl: '  ', categoryId: 1),
      throwsArgumentError,
    );
    await expectLater(
      client.createFeed(feedUrl: 'https://e.com/feed.xml', categoryId: 0),
      throwsArgumentError,
    );
    expect(requests, isEmpty);

    final created = await client.createFeed(
      feedUrl: ' https://e.com/feed.xml ',
      categoryId: 4,
    );
    expect(created['id'], 3);
    expect(requests.single.data, {
      'feed_url': 'https://e.com/feed.xml',
      'category_id': 4,
    });
  });

  test(
    'updateFeed sends only provided fields and rejects empty updates',
    () async {
      final requests = <_RecordedRequest>[];
      final client = MinifluxClient(
        dio: _dio(requests, data: {'id': 3}),
        baseUrl: 'https://miniflux.example.com',
        apiToken: 'token',
      );

      await expectLater(client.updateFeed(feedId: 3), throwsArgumentError);
      await expectLater(
        client.updateFeed(feedId: 3, title: '   '),
        throwsArgumentError,
      );
      expect(requests, isEmpty);

      await client.updateFeed(feedId: 3, title: ' Renamed ');
      expect(requests.single.path, '/v1/feeds/3');
      expect(requests.single.data, {'title': 'Renamed'});
    },
  );

  test('category and feed mutations hit expected endpoints', () async {
    final requests = <_RecordedRequest>[];
    final client = MinifluxClient(
      dio: _dio(requests, data: {'id': 8, 'title': 'Tech'}),
      baseUrl: 'https://miniflux.example.com',
      apiToken: 'token',
    );

    await client.createCategory(' Tech ');
    await client.updateCategory(categoryId: 8, title: 'Tech 2');
    await client.deleteCategory(8);
    await client.deleteFeed(3);
    await client.refreshFeed(3);
    await client.refreshAllFeeds();
    await client.markFeedAllAsRead(3);
    await client.markCategoryAllAsRead(8);

    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'POST /v1/categories',
      'PUT /v1/categories/8',
      'DELETE /v1/categories/8',
      'DELETE /v1/feeds/3',
      'PUT /v1/feeds/3/refresh',
      'PUT /v1/feeds/refresh',
      'PUT /v1/feeds/3/mark-all-as-read',
      'PUT /v1/categories/8/mark-all-as-read',
    ]);
    expect(requests.first.data, {'title': 'Tech'});
  });
}

Dio _dio(List<_RecordedRequest> requests, {Object? data}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
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
      queryParameters: Map<String, List<String>>.from(
        options.uri.queryParametersAll,
      ),
      headers: Map<String, Object?>.from(options.headers),
      data: options.data,
    );
  }

  final String method;
  final String path;
  final Map<String, List<String>> queryParameters;
  final Map<String, Object?> headers;
  final Object? data;
}
