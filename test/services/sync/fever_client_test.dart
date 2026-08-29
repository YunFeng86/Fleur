import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/fever/fever_client.dart';

void main() {
  test('FeverClient rejects partially malformed id lists', () async {
    final client = FeverClient(
      dio: _dioFor(<Object?>[1, 1.5, '2', double.infinity]),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );

    await expectLater(client.getUnreadItemIds(), throwsStateError);
  });

  test('FeverClient accepts empty and valid id lists', () async {
    final empty = FeverClient(
      dio: _dioFor(''),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );
    expect(await empty.getUnreadItemIds(), isEmpty);

    final valid = FeverClient(
      dio: _dioFor(<Object?>[1, '2']),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );
    expect(await valid.getUnreadItemIds(), [1, 2]);
  });

  test('FeverClient rejects non-finite auth values as auth failures', () async {
    final client = FeverClient(
      dio: _dioFor(const [], auth: double.infinity),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );

    await expectLater(client.validate(), throwsA(isA<FeverAuthException>()));
  });

  test(
    'FeverClient rejects missing and partially malformed list fields',
    () async {
      final missing = FeverClient(
        dio: _dioFor(const [], includeUnreadItemIds: false),
        baseUrl: 'https://fever.example.com',
        apiKey: 'api-key',
      );
      await expectLater(missing.getFeeds(), throwsStateError);
      await expectLater(missing.getUnreadItemIds(), throwsStateError);

      final malformed = FeverClient(
        dio: _dioFor(const [
          {'id': 1},
          'garbage',
        ], responseField: 'feeds'),
        baseUrl: 'https://fever.example.com',
        apiKey: 'api-key',
      );
      await expectLater(malformed.getFeeds(), throwsStateError);
    },
  );
}

Dio _dioFor(
  Object? responseValue, {
  Object? auth = 1,
  String responseField = 'unread_item_ids',
  bool includeUnreadItemIds = true,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: <String, Object?>{
              'auth': auth,
              if (includeUnreadItemIds) responseField: responseValue,
            },
          ),
        );
      },
    ),
  );
  return dio;
}
