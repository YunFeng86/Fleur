import 'dart:convert';
import 'dart:io';

import '../../utils/path_utils.dart';

class ImageMeta {
  const ImageMeta({
    required this.width,
    required this.height,
    required this.updatedAt,
  });

  final double width;
  final double height;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ImageMeta? fromJson(Map<String, Object?> json) {
    final width = json['width'];
    final height = json['height'];
    final updatedAt = json['updatedAt'];
    if (width is! num || height is! num) return null;
    if (updatedAt is! String) return null;
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    if (width <= 0 || height <= 0) return null;
    return ImageMeta(
      width: width.toDouble(),
      height: height.toDouble(),
      updatedAt: parsedUpdatedAt,
    );
  }
}

class ImageMetaStore {
  static const int _maxEntries = 2000;
  Map<String, ImageMeta>? _cache;

  ImageMeta? peek(String url) {
    final cached = _cache;
    if (cached == null) return null;
    return cached[url];
  }

  Future<ImageMeta?> get(String url) async {
    final all = await _loadAll();
    return all[url];
  }

  Future<Map<String, ImageMeta>> getMany(Iterable<String> urls) async {
    final all = await _loadAll();
    final out = <String, ImageMeta>{};
    for (final url in urls) {
      final meta = all[url];
      if (meta != null) out[url] = meta;
    }
    return out;
  }

  Future<void> saveMany(Map<String, ImageMeta> entries) async {
    if (entries.isEmpty) return;
    final all = await _loadAll();
    final next = Map<String, ImageMeta>.from(all);
    next.addAll(entries);
    _trimIfNeeded(next);
    _cache = next;
    await _writeAll(next);
  }

  Future<void> clear() async {
    _cache = <String, ImageMeta>{};
    final f = await _file();
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<Map<String, ImageMeta>> _loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final f = await _file();
      if (!await f.exists()) {
        _cache = <String, ImageMeta>{};
        return _cache!;
      }
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = <String, ImageMeta>{};
        return _cache!;
      }
      final out = <String, ImageMeta>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) continue;
        if (entry.value is! Map) continue;
        final data = (entry.value as Map).cast<String, Object?>();
        final parsed = ImageMeta.fromJson(data);
        if (parsed == null) continue;
        out[entry.key as String] = parsed;
      }
      _cache = out;
      return out;
    } catch (_) {
      _cache = <String, ImageMeta>{};
      return _cache!;
    }
  }

  Future<void> _writeAll(Map<String, ImageMeta> data) async {
    final f = await _file();
    final encoded = <String, Object?>{};
    for (final entry in data.entries) {
      encoded[entry.key] = entry.value.toJson();
    }
    await f.writeAsString(jsonEncode(encoded), encoding: utf8);
  }

  Future<File> _file() async {
    final dir = await PathUtils.getAppDataDirectory();
    return File('${dir.path}${Platform.pathSeparator}image_meta.json');
  }

  void _trimIfNeeded(Map<String, ImageMeta> data) {
    if (data.length <= _maxEntries) return;
    final entries = data.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    final removeCount = entries.length - _maxEntries;
    for (var i = 0; i < removeCount; i++) {
      data.remove(entries[i].key);
    }
  }
}
