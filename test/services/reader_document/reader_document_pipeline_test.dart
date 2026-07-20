import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/reader_chunk_policy.dart';
import 'package:fleur/services/reader_document/reader_document_cache.dart';
import 'package:fleur/services/reader_document/reader_document_models.dart';
import 'package:fleur/services/reader_document/reader_document_pipeline.dart';
import 'package:fleur/utils/content_hash.dart';

void main() {
  group('ReaderDocumentPipeline', () {
    test('processing revisions produce distinct document identities', () {
      const contentRevision = 'extracted:abc';

      final previous = versionReaderDocumentSourceRevision(
        contentRevision,
        processingRevision: 1,
      );
      final current = versionReaderDocumentSourceRevision(contentRevision);

      expect(previous, isNot(current));
      expect(current, endsWith(':$readerDocumentProcessingRevision'));
    });

    test('builds a stable sanitized snapshot for the same request', () {
      const request = ReaderDocumentRequest(
        articleId: '42',
        sourceRevision: 'feed:abc',
        rawHtml:
            '<p onclick="evil()">Hello \$x\$</p>'
            '<script>window.bad()</script>'
            '<img src="/image.png">',
        baseUrl: 'https://example.com/posts/a',
        displayMode: ReaderDisplayMode.source,
        typography: ReaderTypographySettings(
          fontSize: 16,
          minimumFontSize: 12,
          lineHeight: 1.6,
          horizontalPadding: 18,
        ),
        primaryLanguage: 'en',
      );
      const pipeline = ReaderDocumentPipeline(
        chunkPolicy: ReaderChunkPolicy(lengthThreshold: 20),
      );

      final first = pipeline
          .build(request: request, cache: ReaderDocumentCache())
          .snapshot;
      final second = pipeline
          .build(request: request, cache: ReaderDocumentCache())
          .snapshot;

      expect(second.documentKey, first.documentKey);
      expect(second.displayHtml, first.displayHtml);
      expect(second.displayHtml, contains('Hello'));
      expect(second.displayHtml, contains('fleur-math'));
      expect(second.displayHtml, isNot(contains('onclick')));
      expect(second.displayHtml, isNot(contains('window.bad')));
      expect(second.contentHash, ContentHash.compute(second.displayHtml));
      expect(second.primaryLanguage, 'en');
      expect(
        second.chunks.map((range) => range.stableAnchor).toList(),
        first.chunks.map((range) => range.stableAnchor).toList(),
      );
    });

    test(
      'chunk ranges cover the source html without copying chunk strings',
      () {
        final html = List<String>.generate(
          12,
          (index) => '<p>Paragraph $index ${'content ' * 4}</p>',
        ).join();

        final ranges = ReaderDocumentPipeline.splitHtmlIntoRanges(
          html,
          chunkSize: 80,
        );

        expect(ranges.length, greaterThan(1));
        expect(ranges.first.start, 0);
        expect(ranges.last.end, html.length);
        expect(
          ranges.map((range) => html.substring(range.start, range.end)).join(),
          html,
        );
        for (var i = 0; i < ranges.length; i++) {
          final range = ranges[i];
          expect(range.index, i);
          expect(range.start, lessThan(range.end));
          expect(range.estimatedBytes, greaterThan(0));
          expect(range.stableAnchor, 'chunk-$i-${range.start}-${range.end}');
        }
      },
    );

    test(
      'materializes visible ranges lazily and releases transient chunks',
      () {
        final html = List<String>.generate(
          10,
          (index) => '<p>Visible range $index ${'content ' * 5}</p>',
        ).join();
        final cache = ReaderDocumentCache();
        const pipeline = ReaderDocumentPipeline(
          chunkPolicy: ReaderChunkPolicy(lengthThreshold: 10),
        );
        final handle = pipeline.build(
          request: ReaderDocumentRequest(
            articleId: '7',
            sourceRevision: 'feed:lazy',
            rawHtml: html,
            baseUrl: 'https://example.com/article',
            displayMode: ReaderDisplayMode.source,
            typography: const ReaderTypographySettings(
              fontSize: 15,
              minimumFontSize: 12,
              lineHeight: 1.6,
              horizontalPadding: 16,
            ),
          ),
          cache: cache,
        );

        expect(cache.materializedChunkCount, 0);
        final range = handle.snapshot.chunks.first;
        expect(handle.materializeRange(range), handle.snapshot.displayHtml);
        expect(cache.materializedChunkCount, 1);

        handle.releaseTransientSearchArtifacts();
        expect(cache.materializedChunkCount, 0);
      },
    );
  });
}
