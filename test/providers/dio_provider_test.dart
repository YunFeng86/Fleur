import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/providers/dio_provider.dart';
import 'package:fleur/services/network/size_limited_adapter.dart';

void main() {
  Uri uri(String path) => Uri.parse('https://example.com$path');

  ResponseBody bodyOf(
    List<int> bytes, {
    int? contentLength,
    String? contentType,
  }) {
    return ResponseBody(
      Stream<Uint8List>.value(Uint8List.fromList(bytes)),
      200,
      headers: {
        if (contentType != null) Headers.contentTypeHeader: [contentType],
        if (contentLength != null)
          Headers.contentLengthHeader: ['$contentLength'],
      },
    );
  }

  test('responses within the limit pass through and decode as json', () async {
    final dio = createAppDio(
      maxResponseBytes: 1024,
      adapter: _FixedAdapter(
        (options) async =>
            bodyOf(utf8.encode('{"ok":true}'), contentType: 'application/json'),
      ),
    );
    addTearDown(dio.close);

    final response = await dio.getUri<Map<String, Object?>>(uri('/api'));
    expect(response.data, {'ok': true});
  });

  test('plain text responses within the limit pass through', () async {
    final dio = createAppDio(
      maxResponseBytes: 1024,
      adapter: _FixedAdapter(
        (options) async =>
            bodyOf(utf8.encode('<rss>hello</rss>'), contentType: 'text/xml'),
      ),
    );
    addTearDown(dio.close);

    final response = await dio.getUri<String>(
      uri('/feed.xml'),
      options: Options(responseType: ResponseType.plain),
    );
    expect(response.data, contains('hello'));
  });

  test(
    'declared content-length over the limit is rejected before download',
    () async {
      var downloaded = false;
      final dio = createAppDio(
        maxResponseBytes: 16,
        adapter: _FixedAdapter((options) async {
          downloaded = true;
          return bodyOf(List<int>.filled(128, 0x61), contentLength: 128);
        }),
      );
      addTearDown(dio.close);

      await expectLater(
        dio.getUri<Object?>(uri('/big')),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<ResponseTooLargeException>(),
          ),
        ),
      );
      expect(downloaded, isTrue);
    },
  );

  test('chunked bodies exceeding the limit abort mid-stream', () async {
    final controller = StreamController<Uint8List>();
    var bytesPulled = 0;
    final source = controller.stream.map((chunk) {
      bytesPulled += chunk.length;
      return chunk;
    });
    final dio = createAppDio(
      maxResponseBytes: 32,
      adapter: _FixedAdapter(
        (options) async => ResponseBody(
          source,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      ),
    );
    addTearDown(dio.close);

    final future = dio.getUri<Object?>(uri('/chunked'));
    // Feed more chunks than the limit allows; delivery is pulled by dio's
    // transformer so schedule asynchronously.
    scheduleMicrotask(() {
      controller.add(Uint8List.fromList(List<int>.filled(16, 0x61)));
      controller.add(Uint8List.fromList(List<int>.filled(16, 0x61)));
      controller.add(Uint8List.fromList(List<int>.filled(16, 0x61)));
    });

    await expectLater(
      future,
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<ResponseTooLargeException>(),
        ),
      ),
    );
    // The third chunk (which crosses the cap) must abort consumption before
    // the whole body is buffered.
    expect(bytesPulled, lessThan(48 + 16));
    await controller.close();
  });
}

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}
