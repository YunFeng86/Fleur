import 'dart:convert';
import 'dart:io';

import '../../utils/path_utils.dart';

class ReaderProgress {
  const ReaderProgress({
    required this.articleId,
    required this.contentHash,
    required this.pixels,
    required this.progress,
    required this.updatedAt,
  });

  final int articleId;
  final String contentHash;
  final double pixels;
  final double progress;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'articleId': articleId,
    'contentHash': contentHash,
    'pixels': pixels,
    'progress': progress,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ReaderProgress? fromJson(Map<String, Object?> json) {
    final articleId = json['articleId'];
    final contentHash = json['contentHash'];
    final pixels = json['pixels'];
    final progress = json['progress'];
    final updatedAt = json['updatedAt'];
    if (articleId is! num) return null;
    if (contentHash is! String || contentHash.trim().isEmpty) return null;
    if (pixels is! num || progress is! num) return null;
    if (updatedAt is! String) return null;
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;

    return ReaderProgress(
      articleId: articleId.toInt(),
      contentHash: contentHash.trim(),
      pixels: pixels.toDouble(),
      progress: progress.toDouble().clamp(0.0, 1.0).toDouble(),
      updatedAt: parsedUpdatedAt,
    );
  }
}

class ReaderProgressStore {
  static const int _maxEntries = 240;
  Map<String, ReaderProgress>? _cache;

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
    final all = await _loadAll();
    final next = Map<String, ReaderProgress>.from(all);
    next[_keyFor(progress.articleId, progress.contentHash)] = progress;
    _trimIfNeeded(next);
    _cache = next;
    await _writeAll(next);
  }

  Future<Map<String, ReaderProgress>> _loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final f = await _file();
      if (!await f.exists()) {
        _cache = <String, ReaderProgress>{};
        return _cache!;
      }
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = <String, ReaderProgress>{};
        return _cache!;
      }
      final out = <String, ReaderProgress>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) continue;
        if (entry.value is! Map) continue;
        final data = (entry.value as Map).cast<String, Object?>();
        final parsed = ReaderProgress.fromJson(data);
        if (parsed == null) continue;
        out[entry.key as String] = parsed;
      }
      _cache = out;
      return out;
    } catch (_) {
      _cache = <String, ReaderProgress>{};
      return _cache!;
    }
  }

  Future<void> _writeAll(Map<String, ReaderProgress> data) async {
    final f = await _file();
    final encoded = <String, Object?>{};
    for (final entry in data.entries) {
      encoded[entry.key] = entry.value.toJson();
    }
    await f.writeAsString(jsonEncode(encoded), encoding: utf8);
  }

  Future<File> _file() async {
    final dir = await PathUtils.getAppDataDirectory();
    return File('${dir.path}${Platform.pathSeparator}reader_progress.json');
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
