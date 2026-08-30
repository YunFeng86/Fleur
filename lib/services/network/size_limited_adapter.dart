import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Thrown (wrapped in a [DioException]) when a response body exceeds the
/// configured byte limit.
class ResponseTooLargeException implements IOException {
  const ResponseTooLargeException({
    required this.limitBytes,
    required this.observedBytes,
    required this.declaredContentLength,
    required this.mode,
    required this.method,
    required this.host,
    required this.path,
  });

  final int limitBytes;
  final int observedBytes;
  final int? declaredContentLength;
  final String mode;
  final String method;
  final String host;
  final String path;

  @override
  String toString() =>
      'Response exceeded limit (limitBytes=$limitBytes, '
      'observedBytes=$observedBytes, mode=$mode, method=$method, '
      'host=$host, path=$path)';
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
      await _cancelStream(body.stream);
      throw _tooLarge(
        options,
        declared: declared,
        observed: declared,
        mode: 'declared',
      );
    }

    var received = 0;
    final capped = body.stream.transform<Uint8List>(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          received += chunk.length;
          if (received > maxBytes) {
            sink.addError(
              _tooLarge(
                options,
                declared: declared,
                observed: received,
                mode: 'stream',
              ),
            );
            sink.close();
            return;
          }
          sink.add(chunk);
        },
      ),
    );
    // Preserve the transport's close callback and response metadata. Creating
    // a new ResponseBody here would detach both from dio's response lifecycle.
    body.stream = capped;
    return body;
  }

  DioException _tooLarge(
    RequestOptions options, {
    required int? declared,
    required int observed,
    required String mode,
  }) {
    final uri = options.uri;
    return DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: ResponseTooLargeException(
        limitBytes: maxBytes,
        observedBytes: observed,
        declaredContentLength: declared,
        mode: mode,
        method: options.method,
        host: uri.host,
        path: uri.path,
      ),
      message: 'response exceeded the ${maxBytes}B limit',
    );
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }

  Future<void> _cancelStream(Stream<Uint8List> stream) async {
    try {
      await stream.listen(null).cancel();
    } catch (_) {
      // The adapter still reports the size violation if cancellation is not
      // supported by a custom transport.
    }
  }
}
