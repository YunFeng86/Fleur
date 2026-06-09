import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/reader_search_service.dart';

void main() {
  test('splitHtmlIntoChunks keeps pre blocks intact', () {
    final html =
        '<p>${'before ' * 80}</p>'
        '<pre>${'const value = 1;\\n' * 12}</pre>'
        '<p>${'after ' * 80}</p>';

    final chunks = ReaderSearchService.splitHtmlIntoChunks(
      html,
      chunkSize: 120,
    );

    expect(chunks.where((chunk) => chunk.contains('<pre>')), hasLength(1));
    final preChunk = chunks.singleWhere((chunk) => chunk.contains('<pre>'));
    expect(preChunk, contains('</pre>'));
    expect(preChunk, contains('const value = 1;'));
  });

  test('highlightChunks preserves code mark ranges with anchor proxy', () async {
    final service = ReaderSearchService();
    final highlight = await service.highlightChunks(
      chunks: const [
        '<pre><code><span class="token-line">const targetAlpha = 1;<br></span></code></pre>',
      ],
      query: 'target',
      caseSensitive: false,
      anchorPrefix: 'rs-test-',
    );

    expect(highlight.matches, hasLength(1));
    expect(highlight.matches.single.anchorId, 'rs-test-0');
    expect(highlight.highlightedChunks.single, contains('id="rs-test-0"'));
    expect(
      highlight.highlightedChunks.single,
      contains('data-reader-search-proxy="1"'),
    );
    expect(
      highlight.highlightedChunks.single,
      contains('data-reader-search-anchor="rs-test-0"'),
    );
    expect(
      highlight.highlightedChunks.single,
      contains('<mark id="rs-test-0"'),
    );
  });
}
