import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/rss/feed_discovery_service.dart';

Dio _buildDio(
  Map<String, void Function(RequestOptions, RequestInterceptorHandler)> routes,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = '${options.method} ${options.uri.path}';
        final route = routes[key];
        if (route != null) {
          route(options, handler);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'unexpected request: $key',
          ),
        );
      },
    ),
  );
  return dio;
}

Response<String> _response(
  RequestOptions options, {
  required String body,
  required String contentType,
  int statusCode = 200,
}) {
  return Response<String>(
    requestOptions: options,
    statusCode: statusCode,
    data: body,
    headers: Headers.fromMap(<String, List<String>>{
      'content-type': <String>[contentType],
    }),
  );
}

void main() {
  test('direct RSS URL returns a direct candidate with parsed title', () async {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example Feed</title>
    <link>https://example.com</link>
    <description>Desc</description>
  </channel>
</rss>
''';
    final service = FeedDiscoveryService(
      _buildDio({
        'GET /feed.xml': (options, handler) {
          handler.resolve(
            _response(options, body: xml, contentType: 'application/rss+xml'),
          );
        },
      }),
    );

    final feeds = await service.discover('https://example.com/feed.xml');

    expect(feeds, hasLength(1));
    expect(feeds.single.url, 'https://example.com/feed.xml');
    expect(feeds.single.title, 'Example Feed');
    expect(feeds.single.siteUrl, 'https://example.com');
    expect(feeds.single.source, DiscoveredFeedSource.direct);
  });

  test(
    'HTML alternate links resolve relative URLs and site metadata',
    () async {
      const html = '''
<!doctype html>
<html>
  <head>
    <title>Example Site</title>
    <base href="https://example.com/blog/">
    <link rel="alternate" type="application/rss+xml" href="feed.xml" title="Main feed">
  </head>
  <body></body>
</html>
''';
      final service = FeedDiscoveryService(
        _buildDio({
          'GET /blog': (options, handler) {
            handler.resolve(
              _response(options, body: html, contentType: 'text/html'),
            );
          },
        }),
      );

      final feeds = await service.discover('https://example.com/blog');

      expect(feeds, hasLength(1));
      expect(feeds.single.url, 'https://example.com/blog/feed.xml');
      expect(feeds.single.title, 'Main feed');
      expect(feeds.single.siteUrl, 'https://example.com/blog');
      expect(feeds.single.siteTitle, 'Example Site');
      expect(feeds.single.source, DiscoveredFeedSource.alternateLink);
    },
  );

  test('HTML without alternate links probes common feed paths', () async {
    const html = '<!doctype html><html><head><title>Blog</title></head></html>';
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Common Feed</title>
    <link>https://example.com/blog</link>
    <description>Desc</description>
  </channel>
</rss>
''';
    final service = FeedDiscoveryService(
      _buildDio({
        'GET /blog': (options, handler) {
          handler.resolve(
            _response(options, body: html, contentType: 'text/html'),
          );
        },
        'GET /feed.xml': (options, handler) {
          handler.resolve(
            _response(options, body: xml, contentType: 'application/rss+xml'),
          );
        },
      }),
    );

    final feeds = await service.discover('https://example.com/blog');

    expect(feeds, hasLength(1));
    expect(feeds.single.url, 'https://example.com/feed.xml');
    expect(feeds.single.title, 'Common Feed');
    expect(feeds.single.siteUrl, 'https://example.com/blog');
    expect(feeds.single.siteTitle, 'Blog');
    expect(feeds.single.source, DiscoveredFeedSource.commonPath);
  });

  test('common path probe failures do not fail discovery', () async {
    const html = '<!doctype html><html><head><title>Blog</title></head></html>';
    final service = FeedDiscoveryService(
      _buildDio({
        'GET /blog': (options, handler) {
          handler.resolve(
            _response(options, body: html, contentType: 'text/html'),
          );
        },
      }),
    );

    final feeds = await service.discover('https://example.com/blog');

    expect(feeds, isEmpty);
  });
}
