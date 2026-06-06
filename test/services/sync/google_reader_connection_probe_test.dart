import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/google_reader/google_reader_connection_probe.dart';
import 'package:fleur/services/sync/google_reader/google_reader_provider_profile.dart';

void main() {
  test('auto probe selects FreshRSS and normalizes root base URL', () async {
    final requests = <String>[];
    final probe = GoogleReaderConnectionProbe(
      dio: _probeDio(requests, successfulPrefix: '/api/greader.php'),
    );

    final result = await probe.probe(
      baseUrl: 'https://rss.example.com/api/greader.php/reader/api/0',
      username: 'user',
      password: 'secret',
      profileId: GoogleReaderProviderProfiles.autoId,
    );

    expect(result.profile.id, GoogleReaderProviderProfiles.freshRssId);
    expect(result.normalizedBaseUrl, 'https://rss.example.com/');
    expect(result.displayName, 'Reader User');
    expect(requests.first, 'POST /api/greader.php/accounts/ClientLogin');
  });

  test('explicit Miniflux profile normalizes reader API base URL', () async {
    final requests = <String>[];
    final probe = GoogleReaderConnectionProbe(
      dio: _probeDio(requests, successfulPrefix: ''),
    );

    final result = await probe.probe(
      baseUrl: 'https://miniflux.example.com/reader/api/0',
      username: 'user',
      password: 'secret',
      profileId: GoogleReaderProviderProfiles.minifluxId,
    );

    expect(result.profile.id, GoogleReaderProviderProfiles.minifluxId);
    expect(result.normalizedBaseUrl, 'https://miniflux.example.com/');
    expect(requests.first, 'POST /accounts/ClientLogin');
  });

  test('probe failure message is sanitized', () async {
    final probe = GoogleReaderConnectionProbe(
      dio: _failingDio(statusCode: 401),
    );

    await expectLater(
      probe.probe(
        baseUrl: 'https://reader.example.com/root?token=query-secret#frag',
        username: 'user-secret',
        password: 'password-secret',
        profileId: GoogleReaderProviderProfiles.genericId,
      ),
      throwsA(
        isA<GoogleReaderProbeException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('HTTP 401'),
            isNot(contains('password-secret')),
            isNot(contains('query-secret')),
            isNot(contains('user-secret')),
          ),
        ),
      ),
    );
  });
}

Dio _probeDio(List<String> requests, {required String successfulPrefix}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add('${options.method} ${options.uri.path}');
        final path = options.uri.path;
        if (!path.startsWith(successfulPrefix)) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 404,
              ),
            ),
          );
          return;
        }
        final normalized = successfulPrefix.isEmpty
            ? path
            : path.substring(successfulPrefix.length);
        final data = switch ((options.method, normalized)) {
          ('POST', '/accounts/ClientLogin') => 'Auth=login-token\n',
          ('GET', '/reader/api/0/user-info') => {'userName': 'Reader User'},
          ('GET', '/reader/api/0/token') => 'write-token',
          ('GET', '/reader/api/0/stream/items/ids') => {
            'itemRefs': <Object?>[],
          },
          _ => throw StateError('Unexpected request: ${options.method} $path'),
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

Dio _failingDio({required int statusCode}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: statusCode,
            ),
          ),
        );
      },
    ),
  );
  return dio;
}
