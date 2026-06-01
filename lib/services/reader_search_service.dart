import 'package:flutter/foundation.dart' show compute;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ReaderSearchMatch {
  const ReaderSearchMatch({required this.chunkIndex, required this.anchorId});

  final int chunkIndex;
  final String anchorId;
}

class ReaderSearchHighlight {
  const ReaderSearchHighlight({
    required this.highlightedChunks,
    required this.matches,
  });

  final List<String> highlightedChunks;
  final List<ReaderSearchMatch> matches;
}

class ReaderSearchService {
  static const int chunkThreshold = 50000;
  static const int defaultChunkSize = 20000;

  static const String markerAttribute = 'data-reader-search';
  static const String markerAttributeValue = '1';
  static const String markerAnchorAttribute = 'data-reader-search-anchor';
  static const String markerProxyAttribute = 'data-reader-search-proxy';

  static const int _asyncThreshold = 50000;

  /// Splits HTML into chunks trying to keep block tags intact.
  static List<String> splitHtmlIntoChunks(
    String html, {
    int chunkSize = defaultChunkSize,
  }) {
    final chunks = <String>[];
    int start = 0;
    final blockTagRe = RegExp(
      r'</(p|div|section|article|h[1-6]|ul|ol|table|blockquote|pre)>',
      caseSensitive: false,
    );

    while (start < html.length) {
      if (start + chunkSize >= html.length) {
        chunks.add(html.substring(start));
        break;
      }

      int end = start + chunkSize;
      final match = blockTagRe.firstMatch(html.substring(end));
      if (match != null) {
        end += match.end;
      } else {
        final closeIdx = html.indexOf('>', end);
        if (closeIdx != -1) {
          end = closeIdx + 1;
        }
      }

      chunks.add(html.substring(start, end));
      start = end;
    }

    return chunks;
  }

  Future<ReaderSearchHighlight> highlightChunks({
    required List<String> chunks,
    required String query,
    required bool caseSensitive,
    required String anchorPrefix,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return ReaderSearchHighlight(
        highlightedChunks: chunks,
        matches: const <ReaderSearchMatch>[],
      );
    }

    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    if (totalLength >= _asyncThreshold) {
      return compute(
        _highlightChunksIsolate,
        _HighlightParams(
          chunks: chunks,
          query: q,
          caseSensitive: caseSensitive,
          anchorPrefix: anchorPrefix,
        ),
      );
    }

    return _highlightChunksSync(
      chunks: chunks,
      query: q,
      caseSensitive: caseSensitive,
      anchorPrefix: anchorPrefix,
    );
  }

  static ReaderSearchHighlight _highlightChunksIsolate(
    _HighlightParams params,
  ) {
    return _highlightChunksSync(
      chunks: params.chunks,
      query: params.query,
      caseSensitive: params.caseSensitive,
      anchorPrefix: params.anchorPrefix,
    );
  }

  static ReaderSearchHighlight _highlightChunksSync({
    required List<String> chunks,
    required String query,
    required bool caseSensitive,
    required String anchorPrefix,
  }) {
    final highlighted = <String>[];
    final matches = <ReaderSearchMatch>[];
    int globalIndex = 0;

    for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
      final res = _highlightChunkHtml(
        chunks[chunkIndex],
        query: query,
        caseSensitive: caseSensitive,
        anchorPrefix: anchorPrefix,
        startIndex: globalIndex,
      );
      highlighted.add(res.highlightedHtml);
      for (final id in res.anchorIds) {
        matches.add(ReaderSearchMatch(chunkIndex: chunkIndex, anchorId: id));
      }
      globalIndex = res.nextIndex;
    }

    return ReaderSearchHighlight(
      highlightedChunks: highlighted,
      matches: matches,
    );
  }

  static _ChunkHighlight _highlightChunkHtml(
    String html, {
    required String query,
    required bool caseSensitive,
    required String anchorPrefix,
    required int startIndex,
  }) {
    final fragment = html_parser.parseFragment(html);

    final anchorIds = <String>[];
    int nextIndex = startIndex;
    final needle = caseSensitive ? query : query.toLowerCase();

    bool containsQuery(String text) {
      if (caseSensitive) return text.contains(needle);
      return text.toLowerCase().contains(needle);
    }

    dom.Element? nearestPre(dom.Node node) {
      var cur = node.parent;
      while (cur != null) {
        if (cur.localName == 'pre') return cur;
        cur = cur.parent;
      }
      return null;
    }

    void insertCodeAnchorProxy(dom.Element pre, String id) {
      final parent = pre.parentNode;
      if (parent == null) return;
      final at = parent.nodes.indexOf(pre);
      if (at < 0) return;
      final proxy = dom.Element.tag('span');
      proxy.attributes['id'] = id;
      proxy.attributes[markerProxyAttribute] = markerAttributeValue;
      parent.nodes.insert(at, proxy);
    }

    void visit(dom.Node node) {
      if (node is dom.Element) {
        final tag = node.localName;
        if (tag == 'script' || tag == 'style' || tag == 'noscript') return;
      }

      if (node is dom.Text) {
        final text = node.text;
        if (text.isEmpty) return;
        if (!containsQuery(text)) return;

        final parent = node.parent;
        if (parent == null) return;
        final at = parent.nodes.indexOf(node);
        if (at < 0) return;

        final replacement = <dom.Node>[];
        final haystack = caseSensitive ? text : text.toLowerCase();
        final pre = nearestPre(node);
        int i = 0;
        while (true) {
          final hit = haystack.indexOf(needle, i);
          if (hit < 0) break;
          if (hit > i) {
            replacement.add(dom.Text(text.substring(i, hit)));
          }
          final id = '$anchorPrefix$nextIndex';
          nextIndex++;
          anchorIds.add(id);
          final mark = dom.Element.tag('mark');
          mark.attributes['id'] = id;
          mark.attributes[markerAttribute] = markerAttributeValue;
          if (pre != null) {
            mark.attributes[markerAnchorAttribute] = id;
          }
          mark.nodes.add(dom.Text(text.substring(hit, hit + query.length)));
          replacement.add(mark);
          if (pre != null) {
            insertCodeAnchorProxy(pre, id);
          }
          i = hit + query.length;
          if (i >= text.length) break;
        }
        if (i < text.length) {
          replacement.add(dom.Text(text.substring(i)));
        }

        parent.nodes.removeAt(at);
        parent.nodes.insertAll(at, replacement);
        return;
      }

      if (node.nodes.isEmpty) return;
      final children = List<dom.Node>.from(node.nodes);
      for (final c in children) {
        visit(c);
      }
    }

    visit(fragment);

    return _ChunkHighlight(
      highlightedHtml: fragment.outerHtml,
      anchorIds: anchorIds,
      nextIndex: nextIndex,
    );
  }
}

class _HighlightParams {
  const _HighlightParams({
    required this.chunks,
    required this.query,
    required this.caseSensitive,
    required this.anchorPrefix,
  });

  final List<String> chunks;
  final String query;
  final bool caseSensitive;
  final String anchorPrefix;
}

class _ChunkHighlight {
  const _ChunkHighlight({
    required this.highlightedHtml,
    required this.anchorIds,
    required this.nextIndex,
  });

  final String highlightedHtml;
  final List<String> anchorIds;
  final int nextIndex;
}
