import 'reader_document_cache.dart';
import 'reader_document_models.dart';

final class ReaderDocumentHandle {
  ReaderDocumentHandle({
    required ReaderDocumentSnapshot snapshot,
    required ReaderDocumentCache cache,
  }) : _snapshot = snapshot,
       _cache = cache;

  final ReaderDocumentSnapshot _snapshot;
  final ReaderDocumentCache _cache;

  bool _disposed = false;

  ReaderDocumentSnapshot get snapshot => _snapshot;

  String materializeRange(ReaderChunkRange range) {
    _ensureActive();
    return _cache.materializeRange(_snapshot, range);
  }

  List<String> materializeRanges(Iterable<ReaderChunkRange> ranges) {
    _ensureActive();
    return [
      for (final range in ranges) _cache.materializeRange(_snapshot, range),
    ];
  }

  void releaseTransientSearchArtifacts() {
    if (_disposed) return;
    _cache.releaseMaterializedChunksFor(_snapshot.documentKey);
  }

  void dispose() {
    if (_disposed) return;
    releaseTransientSearchArtifacts();
    _disposed = true;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ReaderDocumentHandle has been disposed');
    }
  }
}
