import 'dart:io';

import '../persistence/durable_json_store.dart';
import '../../utils/path_manager.dart';

class ReaderProgress {
  const ReaderProgress({
    required this.articleId,
    required this.contentHash,
    required this.pixels,
    required this.progress,
    required this.updatedAt,
    this.anchorIndex,
    this.anchorFraction,
  });

  final int articleId;
  final String contentHash;
  final double pixels;
  final double progress;
  final DateTime updatedAt;
  final int? anchorIndex;
  final double? anchorFraction;

  Map<String, Object?> toJson() => {
    'articleId': articleId,
    'contentHash': contentHash,
    'pixels': pixels,
    'progress': progress,
    'updatedAt': updatedAt.toIso8601String(),
    if (anchorIndex != null) 'anchorIndex': anchorIndex,
    if (anchorFraction != null) 'anchorFraction': anchorFraction,
  };

  static ReaderProgress? fromJson(Map<String, Object?> json) {
    final articleId = json['articleId'];
    final contentHash = json['contentHash'];
    final pixels = json['pixels'];
    final progress = json['progress'];
    final updatedAt = json['updatedAt'];
    final anchorIndex = json['anchorIndex'];
    final anchorFraction = json['anchorFraction'];
    if (articleId is! num) return null;
    if (contentHash is! String || contentHash.trim().isEmpty) return null;
    if (pixels is! num || progress is! num) return null;
    if (!articleId.isFinite || !pixels.isFinite || !progress.isFinite) {
      return null;
    }
    if (updatedAt is! String) return null;
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    final parsedAnchorIndex = anchorIndex is num && anchorIndex.isFinite
        ? anchorIndex.toInt()
        : null;
    final parsedAnchorFraction =
        anchorFraction is num && anchorFraction.isFinite
        ? anchorFraction.toDouble().clamp(0.0, 1.0).toDouble()
        : null;

    return ReaderProgress(
      articleId: articleId.toInt(),
      contentHash: contentHash.trim(),
      pixels: pixels.toDouble(),
      progress: progress.toDouble().clamp(0.0, 1.0).toDouble(),
      updatedAt: parsedUpdatedAt,
      anchorIndex: parsedAnchorIndex,
      anchorFraction: parsedAnchorFraction,
    );
  }
}

class ReaderProgressStore {
  static const int _maxEntries = 240;

  Future<ReaderProgress?> getProgress({
    required int articleId,
    required String contentHash,
  }) async {
    if (contentHash.trim().isEmpty) return null;
    final all = await _loadAll();
    return all[_keyFor(articleId, contentHash)];
  }

  Future<void> saveProgress(ReaderProgress progress) async {
    if (progress.contentHash.trim().isEmpty) return;
    final store = await _store();
    await store.runExclusive(() async {
      final all = await _loadAllFrom(store);
      final next = Map<String, ReaderProgress>.from(all);
      next[_keyFor(progress.articleId, progress.contentHash)] = progress;
      _trimIfNeeded(next);
      await store.write(next);
    });
  }

  Future<Map<String, ReaderProgress>> _loadAll() async {
    final store = await _store();
    return _loadAllFrom(store);
  }

  Future<Map<String, ReaderProgress>> _loadAllFrom(
    DurableJsonStore<Map<String, ReaderProgress>> store,
  ) async {
    try {
      final snapshot = await store.read();
      if (snapshot != null) return snapshot.value;
      if (!PathManager.isMigrationComplete) {
        final legacy = await PathManager.legacyReaderProgressFile();
        if (legacy != null) {
          return (await _storeFor(legacy).read())?.value ??
              <String, ReaderProgress>{};
        }
      }
      return <String, ReaderProgress>{};
    } catch (_) {
      return <String, ReaderProgress>{};
    }
  }

  Map<String, ReaderProgress> _decode(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('Reader progress JSON root is not an object');
    }
    final out = <String, ReaderProgress>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final parsed = ReaderProgress.fromJson(
        (entry.value as Map).cast<String, Object?>(),
      );
      if (parsed != null) out[entry.key as String] = parsed;
    }
    return out;
  }

  Object? _encode(Map<String, ReaderProgress> data) {
    return <String, Object?>{
      for (final entry in data.entries) entry.key: entry.value.toJson(),
    };
  }

  Future<DurableJsonStore<Map<String, ReaderProgress>>> _store() async {
    return _storeFor(await _file());
  }

  DurableJsonStore<Map<String, ReaderProgress>> _storeFor(File file) {
    return DurableJsonStore<Map<String, ReaderProgress>>(
      file: file,
      decode: _decode,
      encode: _encode,
    );
  }

  Future<File> _file() async {
    return PathManager.readerProgressFile();
  }

  String _keyFor(int articleId, String contentHash) {
    return '$articleId:$contentHash';
  }

  void _trimIfNeeded(Map<String, ReaderProgress> data) {
    if (data.length <= _maxEntries) return;
    final entries = data.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    final removeCount = entries.length - _maxEntries;
    for (var i = 0; i < removeCount; i++) {
      data.remove(entries[i].key);
    }
  }
}
