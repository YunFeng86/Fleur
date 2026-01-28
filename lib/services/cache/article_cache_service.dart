import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/parser.dart' as html_parser;
import '../../models/article.dart';

class ArticleCacheService {
  ArticleCacheService(this._cacheManager);

  final BaseCacheManager _cacheManager;
  static const int _asyncParseThreshold = 50000;

  Future<void> prefetchImagesFromHtml(
    String html, {
    required Uri? baseUrl,
    int maxImages = 24,
    int maxConcurrent = 4,
  }) async {
    final urls = await _collectImageUrls(
      html,
      baseUrl: baseUrl,
      maxImages: maxImages,
    );
    if (urls.isEmpty) return;

    // Small bounded concurrency: keeps memory/FD usage low.
    final sem = _Semaphore(maxConcurrent);
    final futures = <Future<void>>[];
    for (final u in urls) {
      futures.add(() async {
        await sem.acquire();
        try {
          await _cacheManager.downloadFile(u);
        } catch (_) {
          // Best-effort cache warming; failures are ignored.
        } finally {
          sem.release();
        }
      }());
    }
    await Future.wait(futures);
  }

  Future<int> cacheArticles(
    Iterable<Article> articles, {
    int maxConcurrentArticles = 2,
  }) async {
    final maxConcurrent = maxConcurrentArticles < 1 ? 1 : maxConcurrentArticles;
    int count = 0;
    final batch = <Future<void>>[];

    for (final article in articles) {
      final content = article.fullContentHtml ?? article.contentHtml;
      if (content == null || content.trim().isEmpty) continue;
      batch.add(
        prefetchImagesFromHtml(
          content,
          baseUrl: Uri.tryParse(article.link),
        ),
      );
      if (batch.length >= maxConcurrent) {
        await Future.wait(batch);
        count += batch.length;
        batch.clear();
      }
    }

    if (batch.isNotEmpty) {
      await Future.wait(batch);
      count += batch.length;
    }
    return count;
  }

  Future<List<String>> _collectImageUrls(
    String html, {
    required Uri? baseUrl,
    required int maxImages,
  }) async {
    final limit = maxImages < 1 ? 0 : maxImages;
    if (limit == 0) return const [];
    if (html.length < _asyncParseThreshold) {
      return _extractImageUrlsSync(
        html,
        baseUrl: baseUrl,
        maxImages: limit,
      );
    }
    return compute(
      _extractImageUrlsIsolate,
      _ImageUrlExtractParams(
        html: html,
        baseUrl: baseUrl?.toString(),
        maxImages: limit,
      ),
    );
  }

  static List<String> _extractImageUrlsIsolate(
    _ImageUrlExtractParams params,
  ) {
    return _extractImageUrlsSync(
      params.html,
      baseUrl: params.baseUrl == null ? null : Uri.tryParse(params.baseUrl!),
      maxImages: params.maxImages,
    );
  }

  static List<String> _extractImageUrlsSync(
    String html, {
    required Uri? baseUrl,
    required int maxImages,
  }) {
    if (maxImages <= 0) return const [];
    final doc = html_parser.parse(html);
    final seen = <String>{};
    final urls = <String>[];
    for (final img in doc.querySelectorAll('img')) {
      final raw = img.attributes['src']?.trim();
      if (raw == null || raw.isEmpty) continue;
      if (raw.startsWith('data:')) continue;
      final u = baseUrl?.resolve(raw) ?? Uri.tryParse(raw);
      if (u == null) continue;
      if (!(u.scheme == 'http' || u.scheme == 'https')) continue;
      final normalized = u.toString();
      if (!seen.add(normalized)) continue;
      urls.add(normalized);
      if (urls.length >= maxImages) break;
    }
    return urls;
  }
}

class _Semaphore {
  _Semaphore(this._max);
  final int _max;
  int _cur = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_cur < _max) {
      _cur++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_cur > 0) _cur--;
    if (_waiters.isNotEmpty && _cur < _max) {
      _cur++;
      _waiters.removeAt(0).complete();
    }
  }
}

class _ImageUrlExtractParams {
  const _ImageUrlExtractParams({
    required this.html,
    required this.baseUrl,
    required this.maxImages,
  });

  final String html;
  final String? baseUrl;
  final int maxImages;
}
