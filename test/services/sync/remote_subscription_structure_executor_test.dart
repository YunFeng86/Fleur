import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/miniflux/miniflux_client.dart';
import 'package:fleur/services/sync/remote_subscription_structure_executor.dart';

void main() {
  group('MinifluxRemoteSubscriptionStructureExecutor', () {
    test('creates category and feed through Miniflux endpoints', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(_minifluxDio(requests)),
      );

      final category = await executor.createCategory(' News ');
      final feed = await executor.createFeed(
        feedUrl: ' https://example.com/feed.xml ',
        categoryId: 7,
      );

      expect(category['id'], 7);
      expect(feed['id'], 9);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'POST /v1/categories',
        'POST /v1/feeds',
      ]);
      expect(requests[0].data, {'title': 'News'});
      expect(requests[1].data, {
        'feed_url': 'https://example.com/feed.xml',
        'category_id': 7,
      });
    });

    test('deletes and refreshes feed by normalized feed url', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(
          _minifluxDio(
            requests,
            feeds: [
              {'id': 9, 'feed_url': 'https://example.com/feed.xml'},
            ],
          ),
        ),
      );

      await executor.deleteFeedByUrl('https://example.com/feed.xml/');
      await executor.refreshFeedByUrl('https://example.com/feed.xml/');

      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/feeds',
        'DELETE /v1/feeds/9',
        'GET /v1/feeds',
        'PUT /v1/feeds/9/refresh',
      ]);
    });

    test('renames and deletes category by trimmed title', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(
          _minifluxDio(
            requests,
            categories: [
              {'id': 3, 'title': 'News'},
            ],
          ),
        ),
      );

      final updated = await executor.renameCategoryByTitle(
        currentTitle: ' News ',
        title: 'Latest',
      );
      await executor.deleteCategoryByTitle('News');

      expect(updated['title'], 'Latest');
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/categories',
        'PUT /v1/categories/3',
        'GET /v1/categories',
        'DELETE /v1/categories/3',
      ]);
      expect(requests[1].data, {'title': 'Latest'});
    });

    test('moves feed to category using resolved remote ids', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(
          _minifluxDio(
            requests,
            feeds: [
              {'id': 9, 'feed_url': 'https://example.com/feed.xml'},
            ],
            categories: [
              {'id': 3, 'title': 'News'},
            ],
          ),
        ),
      );

      final updated = await executor.moveFeedToCategory(
        feedUrl: 'https://example.com/feed.xml/',
        categoryTitle: ' News ',
      );

      expect(updated['id'], 9);
      expect(updated['category_id'], 3);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/feeds',
        'GET /v1/categories',
        'PUT /v1/feeds/9',
      ]);
      expect(requests[2].data, {'category_id': 3});
    });

    test('refreshes all feeds through Miniflux refresh-all endpoint', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(_minifluxDio(requests)),
      );

      await executor.refreshAllFeeds();

      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'PUT /v1/feeds/refresh',
      ]);
    });

    test('throws when feed or category scope cannot be resolved', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteSubscriptionStructureExecutor(
        _minifluxClient(_minifluxDio(requests)),
      );

      await expectLater(
        executor.deleteFeedByUrl('https://missing.example.com/feed.xml'),
        throwsStateError,
      );
      await expectLater(
        executor.deleteCategoryByTitle('Missing'),
        throwsStateError,
      );
    });
  });
}

MinifluxClient _minifluxClient(Dio dio) {
  return MinifluxClient(
    dio: dio,
    baseUrl: 'https://miniflux.example.com',
    apiToken: 'token',
  );
}

Dio _minifluxDio(
  List<_RecordedRequest> requests, {
  List<Map<String, Object?>> feeds = const [],
  List<Map<String, Object?>> categories = const [],
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch ((options.method, options.uri.path)) {
          ('GET', '/v1/feeds') => feeds,
          ('GET', '/v1/categories') => categories,
          ('POST', '/v1/categories') => <String, Object?>{
            'id': 7,
            'title': (options.data as Map)['title'] as String,
          },
          ('POST', '/v1/feeds') => <String, Object?>{
            'id': 9,
            'feed_url': (options.data as Map)['feed_url'] as String,
            'category_id': (options.data as Map)['category_id'] as int,
          },
          ('PUT', final path) when path.startsWith('/v1/feeds/9') =>
            <String, Object?>{
              'id': 9,
              'feed_url': 'https://example.com/feed.xml',
              if (options.data is Map)
                'category_id': (options.data as Map)['category_id'],
            },
          ('PUT', '/v1/categories/3') => <String, Object?>{
            'id': 3,
            'title': (options.data as Map)['title'] as String,
          },
          _ => <String, Object?>{},
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
    required this.data,
  });

  factory _RecordedRequest.fromOptions(RequestOptions options) {
    return _RecordedRequest(
      method: options.method,
      path: options.uri.path,
      data: options.data,
    );
  }

  final String method;
  final String path;
  final Object? data;
}
