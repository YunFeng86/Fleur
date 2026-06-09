import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/reader_document/reader_document_cache.dart';
import 'package:fleur/services/reader_document/reader_document_models.dart';

void main() {
  group('ReaderDocumentCache', () {
    test(
      'evicts least recently used snapshots by count and releases chunks',
      () {
        final cache = ReaderDocumentCache(maxSnapshots: 2);
        final first = _snapshot('1', '<p>${'one ' * 10}</p>');
        final second = _snapshot('2', '<p>${'two ' * 10}</p>');
        final third = _snapshot('3', '<p>${'three ' * 10}</p>');

        cache.putSnapshot(first);
        cache.putSnapshot(second);
        cache.materializeRange(first, first.chunks.single);
        expect(cache.snapshotCount, 2);
        expect(cache.materializedChunkCount, 1);

        cache.putSnapshot(third);

        expect(cache.getSnapshot(first.documentKey), isNull);
        expect(cache.getSnapshot(second.documentKey), isNotNull);
        expect(cache.getSnapshot(third.documentKey), isNotNull);
        expect(cache.materializedChunkCount, 0);
      },
    );

    test('evicts materialized chunks by byte budget', () {
      final cache = ReaderDocumentCache(materializedChunkBudgetBytes: 70);
      final snapshot = _snapshot(
        '1',
        '<p>${'first ' * 6}</p><p>${'second ' * 6}</p>',
        splitAt: 45,
      );
      cache.putSnapshot(snapshot);

      cache.materializeRange(snapshot, snapshot.chunks.first);
      expect(cache.materializedChunkCount, 1);

      cache.materializeRange(snapshot, snapshot.chunks.last);

      expect(cache.materializedChunkCount, 1);
      expect(
        cache.materializeRange(snapshot, snapshot.chunks.last),
        snapshot.displayHtml.substring(
          snapshot.chunks.last.start,
          snapshot.chunks.last.end,
        ),
      );
    });

    test('releaseMaterializedChunksFor clears only the requested document', () {
      final cache = ReaderDocumentCache();
      final first = _snapshot('1', '<p>${'one ' * 10}</p>');
      final second = _snapshot('2', '<p>${'two ' * 10}</p>');
      cache.putSnapshot(first);
      cache.putSnapshot(second);
      cache.materializeRange(first, first.chunks.single);
      cache.materializeRange(second, second.chunks.single);

      cache.releaseMaterializedChunksFor(first.documentKey);

      expect(cache.materializedChunkCount, 1);
      expect(
        cache.materializeRange(second, second.chunks.single),
        second.displayHtml,
      );
    });
  });
}

ReaderDocumentSnapshot _snapshot(
  String articleId,
  String html, {
  int? splitAt,
}) {
  final key = ReaderDocumentKey(
    articleId: articleId,
    sourceRevision: 'feed:$articleId',
    baseUrl: 'https://example.com/$articleId',
    displayMode: ReaderDisplayMode.source,
    translationRevision: null,
    typography: const ReaderTypographySettings(
      fontSize: 15,
      minimumFontSize: 12,
      lineHeight: 1.6,
      horizontalPadding: 16,
    ),
  );
  final ranges = splitAt == null
      ? <ReaderChunkRange>[
          ReaderChunkRange(
            index: 0,
            start: 0,
            end: html.length,
            estimatedBytes: html.length,
            stableAnchor: 'chunk-0-0-${html.length}',
          ),
        ]
      : <ReaderChunkRange>[
          ReaderChunkRange(
            index: 0,
            start: 0,
            end: splitAt,
            estimatedBytes: splitAt,
            stableAnchor: 'chunk-0-0-$splitAt',
          ),
          ReaderChunkRange(
            index: 1,
            start: splitAt,
            end: html.length,
            estimatedBytes: html.length - splitAt,
            stableAnchor: 'chunk-1-$splitAt-${html.length}',
          ),
        ];
  return ReaderDocumentSnapshot(
    documentKey: key,
    articleId: articleId,
    displayHtml: html,
    contentByteSize: html.length,
    chunks: ranges,
    primaryLanguage: null,
    renderRevision: key.hashCode,
    isChunked: ranges.length > 1,
    contentHash: 'hash:$articleId',
  );
}
