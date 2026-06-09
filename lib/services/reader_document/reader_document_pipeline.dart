import 'dart:convert';

import '../../utils/content_hash.dart';
import '../feed_html_normalizer.dart';
import '../html_sanitizer.dart';
import '../reader_chunk_policy.dart';
import '../reader_html_normalizer.dart';
import 'reader_document_cache.dart';
import 'reader_document_handle.dart';
import 'reader_document_models.dart';

final class ReaderDocumentPipeline {
  const ReaderDocumentPipeline({
    this.chunkPolicy = ReaderChunkPolicy.defaultPolicy,
  });

  final ReaderChunkPolicy chunkPolicy;

  ReaderDocumentHandle build({
    required ReaderDocumentRequest request,
    required ReaderDocumentCache cache,
  }) {
    final documentKey = request.documentKey;
    final cached = cache.getSnapshot(documentKey);
    if (cached != null) {
      return ReaderDocumentHandle(snapshot: cached, cache: cache);
    }

    final baseUrl = Uri.tryParse(request.baseUrl);
    final normalizedFeedHtml = FeedHtmlNormalizer.normalize(
      request.rawHtml,
      baseUrl: baseUrl,
    );
    final displayHtml = HtmlSanitizer.sanitize(
      normalizeReaderHtmlForDisplay(normalizedFeedHtml),
    ).trim();
    final isChunked = chunkPolicy.shouldUseChunkedLayout(displayHtml);
    final chunks = displayHtml.isEmpty
        ? const <ReaderChunkRange>[]
        : _splitHtmlIntoRanges(displayHtml);
    final snapshot = ReaderDocumentSnapshot(
      documentKey: documentKey,
      articleId: request.articleId,
      displayHtml: displayHtml,
      contentByteSize: utf8.encode(displayHtml).length,
      chunks: chunks,
      primaryLanguage: request.primaryLanguage,
      renderRevision: documentKey.hashCode,
      isChunked: isChunked,
      contentHash: displayHtml.isEmpty ? '' : ContentHash.compute(displayHtml),
    );
    cache.putSnapshot(snapshot);
    return ReaderDocumentHandle(snapshot: snapshot, cache: cache);
  }

  static List<ReaderChunkRange> splitHtmlIntoRanges(
    String html, {
    int chunkSize = 20000,
  }) {
    return _splitHtmlIntoRanges(html, chunkSize: chunkSize);
  }
}

List<ReaderChunkRange> _splitHtmlIntoRanges(
  String html, {
  int chunkSize = 20000,
}) {
  final chunks = <ReaderChunkRange>[];
  var start = 0;
  var index = 0;
  final blockTagRe = RegExp(
    r'</(p|div|section|article|h[1-6]|ul|ol|table|blockquote|pre)>',
    caseSensitive: false,
  );

  while (start < html.length) {
    var end = html.length;
    if (start + chunkSize < html.length) {
      end = start + chunkSize;
      final match = blockTagRe.firstMatch(html.substring(end));
      if (match != null) {
        end += match.end;
      } else {
        final closeIdx = html.indexOf('>', end);
        if (closeIdx != -1) {
          end = closeIdx + 1;
        }
      }
    }

    final range = ReaderChunkRange(
      index: index,
      start: start,
      end: end,
      estimatedBytes: utf8.encode(html.substring(start, end)).length,
      stableAnchor: 'chunk-$index-$start-$end',
    );
    chunks.add(range);
    start = end;
    index++;
  }

  return chunks;
}
