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
}
