import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../network/user_agents.dart';
import 'article_extractor_core.dart';

export 'article_extractor_core.dart'
    show
        ArticleExtractionDiagnostics,
        ArticleExtractionFailureReason,
        ExtractedArticle;

class ArticleExtractor {
  ArticleExtractor(this._dio);

  final Dio _dio;

  Future<ExtractedArticle> extract(String url, {String? userAgent}) async {
    final html = await _fetchHtml(url, userAgent: userAgent);
    // Use compute to parse HTML in a separate isolate to avoid blocking the UI thread.
    return compute(_extractInIsolate, _ExtractParams(html: html, url: url));
  }

  Future<String> _fetchHtml(String url, {String? userAgent}) async {
    final ua = (userAgent != null && userAgent.trim().isNotEmpty)
        ? userAgent.trim()
        : UserAgents.webForCurrentPlatform();
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          if (!kIsWeb) 'User-Agent': ua,
        },
      ),
    );
    return res.data ?? '';
  }

  static ExtractedArticle _extractInIsolate(_ExtractParams params) {
    return extractFromHtml(html: params.html, url: params.url);
  }

  static ExtractedArticle extractFromHtml({
    required String html,
    required String url,
  }) {
    return ArticleExtractorCore.extractFromHtml(html: html, url: url);
  }

  static ArticleExtractionDiagnostics diagnoseFromHtml({
    required String html,
    required String url,
    int? statusCode,
  }) {
    return ArticleExtractorCore.diagnoseFromHtml(
      html: html,
      url: url,
      statusCode: statusCode,
    );
  }
}

class _ExtractParams {
  final String html;
  final String url;
  _ExtractParams({required this.html, required this.url});
}
