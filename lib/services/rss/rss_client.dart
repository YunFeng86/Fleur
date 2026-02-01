import 'package:dio/dio.dart';

import '../network/user_agents.dart';

class RssFetchResult {
  const RssFetchResult({
    required this.statusCode,
    required this.body,
    this.etag,
    this.lastModified,
  });

  final int statusCode;
  final String body;
  final String? etag;
  final String? lastModified;
}

class RssClient {
  RssClient(this._dio);

  final Dio _dio;

  Future<RssFetchResult> fetchXml(
    String url, {
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        // Accept 304 so callers can handle "not modified" without exceptions.
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        headers: const {
          'Accept': 'application/rss+xml, application/atom+xml, text/xml, */*',
          'User-Agent': UserAgents.rss,
        }
            .map((k, v) => MapEntry(k, v))
            ..addAll({
              if (ifNoneMatch != null && ifNoneMatch.trim().isNotEmpty)
                'If-None-Match': ifNoneMatch,
              if (ifModifiedSince != null && ifModifiedSince.trim().isNotEmpty)
                'If-Modified-Since': ifModifiedSince,
            }),
      ),
    );
    final status = res.statusCode ?? 0;
    return RssFetchResult(
      statusCode: status,
      body: res.data ?? '',
      etag: res.headers.value('etag'),
      lastModified: res.headers.value('last-modified'),
    );
  }
}
