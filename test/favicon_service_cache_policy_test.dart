import 'package:dio/dio.dart';
import 'package:flutter_reader/services/cache/favicon_store.dart';
import 'package:flutter_reader/services/network/favicon_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestFaviconStore extends FaviconStore {
  final Map<String, FaviconCacheEntry> _map = <String, FaviconCacheEntry>{};

  int setCalls = 0;

  @override
  Future<FaviconCacheEntry?> get(String host) async {
    return _map[host];
  }

  @override
  Future<void> set(String host, FaviconCacheEntry entry) async {
    setCalls++;
    _map[host] = entry;
  }

  FaviconCacheEntry? peek(String host) => _map[host];
}

void main() {
  test('Error: does not persist favicon resolution', () async {
    final store = _TestFaviconStore();
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Simulate offline/timeout for all requests.
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );

    final service = FaviconService(dio: dio, store: store);
    final out = await service.resolveFaviconUrl(
      Uri.parse('https://example.com/some/path'),
    );

    expect(out, isNull);
    expect(store.setCalls, 0);
  });

  test('Miss (404): persists null for a short TTL', () async {
    final store = _TestFaviconStore();
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final url = options.uri.toString();

          // Home page HTML fetch fails (not important for this test).
          if (options.method == 'GET' &&
              (url == 'https://example.com/' || url == 'http://example.com/')) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
            return;
          }

          // /favicon.ico is a definite miss.
          if ((options.method == 'HEAD' || options.method == 'GET') &&
              (url == 'https://example.com/favicon.ico' ||
                  url == 'http://example.com/favicon.ico')) {
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 404),
            );
            return;
          }

          handler.reject(DioException(requestOptions: options));
        },
      ),
    );

    final service = FaviconService(dio: dio, store: store);
    final out = await service.resolveFaviconUrl(
      Uri.parse('https://example.com'),
    );

    expect(out, isNull);
    expect(store.setCalls, 1);
    expect(store.peek('example.com')?.iconUrl, isNull);
  });

  test('Success: persists resolved icon URL', () async {
    final store = _TestFaviconStore();
    final dio = Dio();

    const iconUrl = 'https://cdn.example.com/icon.png';
    const html =
        '''
<!doctype html>
<html>
  <head>
    <link rel="icon" href="$iconUrl">
  </head>
  <body>ok</body>
</html>
''';

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final url = options.uri.toString();

          if (options.method == 'GET' && url == 'https://example.com/') {
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data: html,
              ),
            );
            return;
          }

          // The reachability probe for the candidate icon URL.
          if (options.method == 'HEAD' && url == iconUrl) {
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 200),
            );
            return;
          }

          // Let any unexpected requests fail fast so tests stay strict.
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );

    final service = FaviconService(dio: dio, store: store);
    final out = await service.resolveFaviconUrl(
      Uri.parse('https://example.com'),
    );

    expect(out, iconUrl);
    expect(store.setCalls, 1);
    expect(store.peek('example.com')?.iconUrl, iconUrl);
  });

  test('429: session backoff prevents retry storm', () async {
    final store = _TestFaviconStore();
    final dio = Dio();

    var requestCount = 0;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          final url = options.uri.toString();

          // Force favicon probing to see 429.
          if ((options.method == 'HEAD' || options.method == 'GET') &&
              (url == 'https://example.com/favicon.ico' ||
                  url == 'http://example.com/favicon.ico')) {
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 429),
            );
            return;
          }

          // Make HTML fetch fail, so we go to /favicon.ico probe quickly.
          if (options.method == 'GET' &&
              (url == 'https://example.com/' || url == 'http://example.com/')) {
            handler.reject(DioException(requestOptions: options));
            return;
          }

          handler.reject(DioException(requestOptions: options));
        },
      ),
    );

    final service = FaviconService(dio: dio, store: store);

    final first = await service.resolveFaviconUrl(
      Uri.parse('https://example.com'),
    );
    final afterFirst = requestCount;
    final second = await service.resolveFaviconUrl(
      Uri.parse('https://example.com/any/path'),
    );

    expect(first, isNull);
    expect(second, isNull);

    // Second call should be short-circuited by session backoff (no extra HTTP).
    expect(requestCount, afterFirst);
    expect(store.setCalls, 0);
  });
}
