import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Thrown (wrapped in a [DioException]) when a response body exceeds the
/// configured byte limit.
class ResponseTooLargeException implements IOException {
  const ResponseTooLargeException(this.uri, this.limitBytes);

  final Uri? uri;
  final int limitBytes;

  @override
  String toString() => 'Response exceeded $limitBytes bytes: $uri';
}

/// [HttpClientAdapter] decorator that bounds how many response bytes dio is
/// allowed to buffer.
///
/// Dio's default pipeline fully buffers every response, so a misbehaving or
/// hostile server can exhaust memory even with receive timeouts in place (the
/// timeout only guards idle gaps between chunks). This adapter:
/// - rejects responses whose declared `Content-Length` already exceeds the
///   limit, before the body is downloaded, and
/// - counts bytes of chunked/unknown-length bodies and errors as soon as the
///   cap is crossed.
///
/// Responses within the limit pass through untouched, so dio's usual
/// json/text/bytes decoding and generic typing keep working.
class SizeLimitedHttpClientAdapter implements HttpClientAdapter {
  SizeLimitedHttpClientAdapter({
    required HttpClientAdapter inner,
    required this.maxBytes,
  }) : _inner = inner;

  static const int defaultMaxBytes = 32 * 1024 * 1024; // 32 MiB

  final HttpClientAdapter _inner;
  final int maxBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = await _inner.fetch(options, requestStream, cancelFuture);

    // The getter parses Content-Length and returns -1 when unspecified.
    final declared = body.contentLength;
    if (declared > 0 && declared > maxBytes) {
      throw _tooLarge(options);
    }

    var received = 0;
    final capped = body.stream.transform<Uint8List>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          received += chunk.length;
          if (received > maxBytes) {
            sink.addError(_tooLarge(options));
            sink.close();
            return;
          }
          sink.add(chunk);
        },
      ),
    );
    return ResponseBody(
      capped,
      body.statusCode,
      headers: body.headers,
      statusMessage: body.statusMessage,
      isRedirect: body.isRedirect,
      redirects: body.redirects,
    );
  }

  DioException _tooLarge(RequestOptions options) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: ResponseTooLargeException(options.uri, maxBytes),
      message: 'response exceeded the ${maxBytes}B limit',
    );
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }
}
