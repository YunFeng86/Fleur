import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/sync/remote_client_factory.dart';

void main() {
  group('RemoteClientFactory Miniflux', () {
    test('prefers trimmed token over basic auth', () async {
      final requests = <_RecordedRequest>[];
      final factory = RemoteClientFactory(
        dio: _dio(requests),
        credentials: _FakeCredentialStore(
          apiToken: ' token ',
          basic: (username: 'user', password: 'pass'),
        ),
      );

      final client = await factory.miniflux(_account(AccountType.miniflux));
      await client.getCategories();

      expect(requests.single.headers['X-Auth-Token'], 'token');
      expect(requests.single.headers, isNot(contains('Authorization')));
    });

    test('falls back to basic auth', () async {
      final requests = <_RecordedRequest>[];
      final factory = RemoteClientFactory(
        dio: _dio(requests),
        credentials: _FakeCredentialStore(
          basic: (username: 'user', password: 'pass'),
        ),
      );

      final client = await factory.miniflux(_account(AccountType.miniflux));
      await client.getCategories();

      final expected = base64Encode(utf8.encode('user:pass'));
      expect(requests.single.headers['Authorization'], 'Basic $expected');
      expect(requests.single.headers, isNot(contains('X-Auth-Token')));
    });

    test('throws or returns null for missing setup', () async {
      final factory = RemoteClientFactory(
        dio: _dio(<_RecordedRequest>[]),
        credentials: _FakeCredentialStore(),
      );

      await expectLater(
        factory.miniflux(_account(AccountType.miniflux, baseUrl: null)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Miniflux baseUrl is empty',
          ),
        ),
      );
      expect(
        await factory.minifluxOrNull(
          _account(AccountType.miniflux, baseUrl: null),
        ),
        isNull,
      );

      await expectLater(
        factory.miniflux(_account(AccountType.miniflux)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Miniflux credentials are missing',
          ),
        ),
      );
      expect(
        await factory.minifluxOrNull(_account(AccountType.miniflux)),
        isNull,
      );
    });
  });

  group('RemoteClientFactory Fever', () {
    test('uses trimmed token as api_key', () async {
      final requests = <_RecordedRequest>[];
      final factory = RemoteClientFactory(
        dio: _dio(requests),
        credentials: _FakeCredentialStore(apiToken: ' api-key '),
      );

      final client = await factory.fever(_account(AccountType.fever));
      await client.getFeeds();

      final payload = requests.single.data as Map<String, Object?>;
      expect(payload['api_key'], 'api-key');
    });

    test('falls back to md5(username:password) basic auth api_key', () async {
      final requests = <_RecordedRequest>[];
      final factory = RemoteClientFactory(
        dio: _dio(requests),
        credentials: _FakeCredentialStore(
          basic: (username: 'user', password: 'pass'),
        ),
      );

      final client = await factory.fever(_account(AccountType.fever));
      await client.getFeeds();

      final expected = md5.convert(utf8.encode('user:pass')).toString();
      final payload = requests.single.data as Map<String, Object?>;
      expect(payload['api_key'], expected);
    });

    test('throws or returns null for missing setup', () async {
      final factory = RemoteClientFactory(
        dio: _dio(<_RecordedRequest>[]),
        credentials: _FakeCredentialStore(),
      );

      await expectLater(
        factory.fever(_account(AccountType.fever, baseUrl: null)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Fever baseUrl is empty',
          ),
        ),
      );
      expect(
        await factory.feverOrNull(_account(AccountType.fever, baseUrl: null)),
        isNull,
      );

      await expectLater(
        factory.fever(_account(AccountType.fever)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Fever credentials are missing',
          ),
        ),
      );
      expect(await factory.feverOrNull(_account(AccountType.fever)), isNull);
    });
  });
}

Account _account(AccountType type, {String? baseUrl = 'https://example.com'}) {
  final now = DateTime.utc(2026);
  return Account(
    id: 'account-${type.name}',
    type: type,
    name: type.name,
    baseUrl: baseUrl,
    createdAt: now,
    updatedAt: now,
  );
}

Dio _dio(List<_RecordedRequest> requests) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch ((options.method, options.uri.path)) {
          ('GET', '/v1/categories') => <Map<String, Object?>>[],
          _ => <String, Object?>{'auth': 1, 'feeds': <Map<String, Object?>>[]},
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

class _FakeCredentialStore extends CredentialStore {
  _FakeCredentialStore({this.apiToken, this.basic});

  final String? apiToken;
  final ({String username, String password})? basic;

  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return apiToken;
  }

  @override
  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return basic;
  }
}

class _RecordedRequest {
  _RecordedRequest({required this.headers, required this.data});

  factory _RecordedRequest.fromOptions(RequestOptions options) {
    return _RecordedRequest(
      headers: Map<String, Object?>.from(options.headers),
      data: options.data,
    );
  }

  final Map<String, Object?> headers;
  final Object? data;
}
