import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/fever/fever_client.dart';
import 'package:fleur/services/sync/miniflux/miniflux_client.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/services/sync/remote_article_action_executor.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  group('MinifluxRemoteArticleActionExecutor', () {
    test('applies markRead to entries endpoint', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteArticleActionExecutor(
        _minifluxClient(_minifluxDio(requests)),
      );

      final applied = await executor.apply(
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 42,
          value: true,
          createdAt: now,
        ),
      );

      expect(applied, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'PUT');
      expect(requests.single.path, '/v1/entries');
      final payload = requests.single.data as Map<String, Object?>;
      expect(payload['entry_ids'], [42]);
      expect(payload['status'], 'read');
    });

    test('applies bookmark through idempotent bookmark state', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteArticleActionExecutor(
        _minifluxClient(_minifluxDio(requests, starred: {42: false})),
      );

      final applied = await executor.apply(
        OutboxAction(
          type: OutboxActionType.bookmark,
          remoteEntryId: 42,
          value: true,
          createdAt: now,
        ),
      );

      expect(applied, isTrue);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/entries/42',
        'PUT /v1/entries/42/bookmark',
      ]);
    });

    test('applies feed-scoped markAllRead with normalized feed url', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteArticleActionExecutor(
        _minifluxClient(
          _minifluxDio(
            requests,
            feeds: [
              {'id': 7, 'feed_url': 'https://example.com/feed.xml'},
            ],
          ),
        ),
      );

      final applied = await executor.apply(
        OutboxAction(
          type: OutboxActionType.markAllRead,
          feedUrl: 'https://example.com/feed.xml/',
          value: true,
          createdAt: now,
        ),
      );

      expect(applied, isTrue);
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /v1/feeds',
        'PUT /v1/feeds/7/mark-all-as-read',
      ]);
    });

    test('returns false for malformed entry-level action', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteArticleActionExecutor(
        _minifluxClient(_minifluxDio(requests)),
      );

      final applied = await executor.apply(
        OutboxAction(type: OutboxActionType.markRead, createdAt: now),
      );

      expect(applied, isFalse);
      expect(requests, isEmpty);
    });

    test('throws when markAllRead feed scope cannot be resolved', () async {
      final requests = <_RecordedRequest>[];
      final executor = MinifluxRemoteArticleActionExecutor(
        _minifluxClient(_minifluxDio(requests, feeds: const [])),
      );

      await expectLater(
        executor.apply(
          OutboxAction(
            type: OutboxActionType.markAllRead,
            feedUrl: 'https://missing.example.com/feed.xml',
            value: true,
            createdAt: now,
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('FeverRemoteArticleActionExecutor', () {
    test('applies markRead and bookmark to item mark queries', () async {
      final requests = <_RecordedRequest>[];
      final executor = FeverRemoteArticleActionExecutor(
        _feverClient(_feverDio(requests)),
      );

      expect(
        await executor.apply(
          OutboxAction(
            type: OutboxActionType.markRead,
            remoteEntryId: 42,
            value: true,
            createdAt: now,
          ),
        ),
        isTrue,
      );
      expect(
        await executor.apply(
          OutboxAction(
            type: OutboxActionType.bookmark,
            remoteEntryId: 99,
            value: false,
            createdAt: now,
          ),
        ),
        isTrue,
      );

      expect(requests, hasLength(2));
      expect(requests[0].query, contains('mark=item'));
      expect(requests[0].query, contains('as=read'));
      expect(requests[0].query, contains('id=42'));
      expect(requests[1].query, contains('mark=item'));
      expect(requests[1].query, contains('as=unsaved'));
      expect(requests[1].query, contains('id=99'));
    });

    test(
      'applies feed and group scoped markAllRead with action timestamp',
      () async {
        final requests = <_RecordedRequest>[];
        final feedExecutor = FeverRemoteArticleActionExecutor(
          _feverClient(
            _feverDio(
              requests,
              feeds: [
                {'id': 7, 'url': 'https://example.com/feed.xml'},
              ],
            ),
          ),
        );

        expect(
          await feedExecutor.apply(
            OutboxAction(
              type: OutboxActionType.markAllRead,
              feedUrl: 'https://example.com/feed.xml/',
              value: true,
              createdAt: now,
            ),
          ),
          isTrue,
        );

        final groupExecutor = FeverRemoteArticleActionExecutor(
          _feverClient(
            _feverDio(
              requests,
              groups: [
                {'id': 5, 'title': 'News'},
              ],
            ),
          ),
        );

        expect(
          await groupExecutor.apply(
            OutboxAction(
              type: OutboxActionType.markAllRead,
              categoryTitle: 'News',
              value: true,
              createdAt: now,
            ),
          ),
          isTrue,
        );

        final beforeSeconds = (now.toUtc().millisecondsSinceEpoch ~/ 1000)
            .toString();
        expect(requests[0].query, 'api&feeds');
        expect(requests[1].query, contains('mark=feed'));
        expect(requests[1].query, contains('id=7'));
        expect(requests[1].query, contains('before=$beforeSeconds'));
        expect(requests[2].query, 'api&groups');
        expect(requests[3].query, contains('mark=group'));
        expect(requests[3].query, contains('id=5'));
        expect(requests[3].query, contains('before=$beforeSeconds'));
      },
    );

    test('returns false for malformed entry-level action', () async {
      final requests = <_RecordedRequest>[];
      final executor = FeverRemoteArticleActionExecutor(
        _feverClient(_feverDio(requests)),
      );

      final applied = await executor.apply(
        OutboxAction(type: OutboxActionType.bookmark, createdAt: now),
      );

      expect(applied, isFalse);
      expect(requests, isEmpty);
    });

    test('throws when markAllRead group scope cannot be resolved', () async {
      final requests = <_RecordedRequest>[];
      final executor = FeverRemoteArticleActionExecutor(
        _feverClient(_feverDio(requests, groups: const [])),
      );

      await expectLater(
        executor.apply(
          OutboxAction(
            type: OutboxActionType.markAllRead,
            categoryTitle: 'Missing',
            value: true,
            createdAt: now,
          ),
        ),
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
  Map<int, bool> starred = const {},
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch ((options.method, options.uri.path)) {
          ('GET', '/v1/feeds') => feeds,
          ('GET', '/v1/categories') => categories,
          ('GET', final path) when path.startsWith('/v1/entries/') => {
            'starred':
                starred[int.tryParse(path.split('/').last) ?? -1] ?? false,
          },
          _ => <String, Object?>{},
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

FeverClient _feverClient(Dio dio) {
  return FeverClient(
    dio: dio,
    baseUrl: 'https://fever.example.com',
    apiKey: 'api-key',
  );
}

Dio _feverDio(
  List<_RecordedRequest> requests, {
  List<Map<String, Object?>> feeds = const [],
  List<Map<String, Object?>> groups = const [],
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch (options.uri.query) {
          'api&feeds' => <String, Object?>{'auth': 1, 'feeds': feeds},
          'api&groups' => <String, Object?>{'auth': 1, 'groups': groups},
          _ => <String, Object?>{'auth': 1},
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
    required this.query,
    required this.data,
  });

  factory _RecordedRequest.fromOptions(RequestOptions options) {
    return _RecordedRequest(
      method: options.method,
      path: options.uri.path,
      query: options.uri.query,
      data: options.data,
    );
  }

  final String method;
  final String path;
  final String query;
  final Object? data;
}
