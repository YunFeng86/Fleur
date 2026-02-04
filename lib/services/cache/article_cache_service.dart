import 'dart:async';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pool/pool.dart';
import 'package:flutter/foundation.dart';
import '../../models/article.dart';
import 'image_meta_store.dart';

class ArticleCacheService {
  ArticleCacheService(this._cacheManager, this._imageMetaStore);

  final BaseCacheManager _cacheManager;
  final ImageMetaStore _imageMetaStore;
  static const int _asyncParseThreshold = 50000;

  Future<void> prefetchImagesFromHtml(
    String html, {
    required Uri? baseUrl,
    int maxImages = 24,
    int maxConcurrent = 4,
    bool recordSizes = true,
  }) async {
    final urls = await _collectImageUrls(
      html,
      baseUrl: baseUrl,
      maxImages: maxImages,
    );
    if (urls.isEmpty) return;

    final existingSizes = recordSizes
        ? await _imageMetaStore.getMany(urls)
        : const <String, ImageMeta>{};

    // 并发上限：避免内存/文件句柄占用过高。
    final pool = Pool(maxConcurrent);
    final futures = <Future<_ImageSizeEntry?>>[];
    for (final u in urls) {
      futures.add(
        pool.withResource(() async {
          try {
            final fileInfo = await _cacheManager.downloadFile(u);
            if (!recordSizes) return null;
            if (existingSizes.containsKey(u)) return null;
            final size = await _decodeImageSize(fileInfo.file);
            if (size == null) return null;
            return _ImageSizeEntry(url: u, size: size);
          } catch (_) {
            // 预热缓存是尽力而为，失败忽略。
            return null;
          }
        }),
      );
    }
    final sizeEntries = await Future.wait(futures);
    await pool.close();

    if (recordSizes) {
      final sizes = <String, ImageMeta>{};
      for (final entry in sizeEntries) {
        if (entry == null) continue;
        sizes[entry.url] = ImageMeta(
          width: entry.size.width.toDouble(),
          height: entry.size.height.toDouble(),
          updatedAt: DateTime.now(),
        );
      }
      if (sizes.isNotEmpty) {
        await _imageMetaStore.saveMany(sizes);
      }
    }
  }

  Future<int> cacheArticles(
    Iterable<Article> articles, {
    int maxConcurrentArticles = 2,
  }) async {
    final maxConcurrent = maxConcurrentArticles < 1 ? 1 : maxConcurrentArticles;
    int count = 0;
    final batch = <Future<void>>[];

    for (final article in articles) {
      final content = article.extractedContentHtml?.trim().isNotEmpty == true
          ? article.extractedContentHtml
          : article.contentHtml;
      if (content == null || content.trim().isEmpty) continue;
      batch.add(
        prefetchImagesFromHtml(
          content,
          baseUrl: Uri.tryParse(article.link),
          maxConcurrent: 3,
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
      return _extractImageUrlsSync(html, baseUrl: baseUrl, maxImages: limit);
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

  static List<String> _extractImageUrlsIsolate(_ImageUrlExtractParams params) {
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

  Future<ui.Size?> _decodeImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
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

class _ImageSizeEntry {
  const _ImageSizeEntry({required this.url, required this.size});

  final String url;
  final ui.Size size;
}
