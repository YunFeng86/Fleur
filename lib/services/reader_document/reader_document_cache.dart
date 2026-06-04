import 'dart:collection';
import 'dart:convert';

import 'reader_document_models.dart';

final class ReaderDocumentCache {
  ReaderDocumentCache({
    this.snapshotBudgetBytes = 4 * 1024 * 1024,
    this.materializedChunkBudgetBytes = 2 * 1024 * 1024,
    this.maxSnapshots = 2,
  });

  final int snapshotBudgetBytes;
  final int materializedChunkBudgetBytes;
  final int maxSnapshots;

  final LinkedHashMap<ReaderDocumentKey, ReaderDocumentSnapshot> _snapshots =
      LinkedHashMap<ReaderDocumentKey, ReaderDocumentSnapshot>();
  final LinkedHashMap<_MaterializedChunkKey, String> _materializedChunks =
      LinkedHashMap<_MaterializedChunkKey, String>();

  int _snapshotBytes = 0;
  int _materializedChunkBytes = 0;

  ReaderDocumentSnapshot? getSnapshot(ReaderDocumentKey key) {
    final snapshot = _snapshots.remove(key);
    if (snapshot == null) return null;
    _snapshots[key] = snapshot;
    return snapshot;
  }

  void putSnapshot(ReaderDocumentSnapshot snapshot) {
    final previous = _snapshots.remove(snapshot.documentKey);
    if (previous != null) {
      _snapshotBytes -= previous.contentByteSize;
    }
    _snapshots[snapshot.documentKey] = snapshot;
    _snapshotBytes += snapshot.contentByteSize;
    _evictSnapshots();
  }

  String materializeRange(
    ReaderDocumentSnapshot snapshot,
    ReaderChunkRange range,
  ) {
    final key = _MaterializedChunkKey(snapshot.documentKey, range.index);
    final cached = _materializedChunks.remove(key);
    if (cached != null) {
      _materializedChunks[key] = cached;
      return cached;
    }

    final html = snapshot.displayHtml.substring(range.start, range.end);
    _materializedChunks[key] = html;
    _materializedChunkBytes += _estimateBytes(html);
    _evictMaterializedChunks();
    return html;
  }

  void releaseMaterializedChunksFor(ReaderDocumentKey key) {
    final staleKeys = [
      for (final entry in _materializedChunks.entries)
        if (entry.key.documentKey == key) entry.key,
    ];
    for (final staleKey in staleKeys) {
      final value = _materializedChunks.remove(staleKey);
      if (value != null) {
        _materializedChunkBytes -= _estimateBytes(value);
      }
    }
  }

  void clear() {
    _snapshots.clear();
    _materializedChunks.clear();
    _snapshotBytes = 0;
    _materializedChunkBytes = 0;
  }

  int get snapshotCount => _snapshots.length;
  int get materializedChunkCount => _materializedChunks.length;
  int get snapshotBytes => _snapshotBytes;
  int get materializedChunkBytes => _materializedChunkBytes;

  void _evictSnapshots() {
    while (_snapshots.length > maxSnapshots ||
        _snapshotBytes > snapshotBudgetBytes) {
      if (_snapshots.isEmpty) return;
      final key = _snapshots.keys.first;
      final removed = _snapshots.remove(key);
      if (removed == null) return;
      _snapshotBytes -= removed.contentByteSize;
      releaseMaterializedChunksFor(key);
    }
  }

  void _evictMaterializedChunks() {
    while (_materializedChunkBytes > materializedChunkBudgetBytes) {
      if (_materializedChunks.isEmpty) return;
      final key = _materializedChunks.keys.first;
      final removed = _materializedChunks.remove(key);
      if (removed == null) return;
      _materializedChunkBytes -= _estimateBytes(removed);
    }
  }

  static int _estimateBytes(String value) => utf8.encode(value).length;
}

final class _MaterializedChunkKey {
  const _MaterializedChunkKey(this.documentKey, this.chunkIndex);

  final ReaderDocumentKey documentKey;
  final int chunkIndex;

  @override
  bool operator ==(Object other) {
    return other is _MaterializedChunkKey &&
        documentKey == other.documentKey &&
        chunkIndex == other.chunkIndex;
  }

  @override
  int get hashCode => Object.hash(documentKey, chunkIndex);
}
