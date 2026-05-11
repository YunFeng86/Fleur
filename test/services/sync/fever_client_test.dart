import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/sync/fever/fever_client.dart';

void main() {
  test('FeverClient skips non-finite ids in id lists', () async {
    final client = FeverClient(
      dio: _dioFor(<Object?>[1, double.infinity, '2', double.nan]),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );

    expect(await client.getUnreadItemIds(), [1, 2]);
  });

  test('FeverClient rejects non-finite auth values as auth failures', () async {
    final client = FeverClient(
      dio: _dioFor(const [], auth: double.infinity),
      baseUrl: 'https://fever.example.com',
      apiKey: 'api-key',
    );

    await expectLater(client.validate(), throwsA(isA<FeverAuthException>()));
  });
}

Dio _dioFor(Object? unreadItemIds, {Object? auth = 1}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: <String, Object?>{
              'auth': auth,
              'unread_item_ids': unreadItemIds,
            },
          ),
        );
      },
    ),
  );
  return dio;
}
