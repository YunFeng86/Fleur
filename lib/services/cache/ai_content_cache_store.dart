import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../utils/path_manager.dart';
import '../translation/article_translation.dart';

enum AiContentCacheKind { summary, translation }

class AiContentCacheKey {
  const AiContentCacheKey.summary({
    required this.accountId,
    required this.articleId,
    required this.targetLanguageTag,
    required this.aiServiceId,
  }) : kind = AiContentCacheKind.summary,
       translationMode = null,
       translationProviderKind = null,
       translationProviderServiceId = null;

  const AiContentCacheKey.translation({
    required this.accountId,
    required this.articleId,
    required this.targetLanguageTag,
    required this.translationMode,
    required this.translationProviderKind,
    required this.translationProviderServiceId,
  }) : kind = AiContentCacheKind.translation,
       aiServiceId = null;

  final String accountId;
  final int articleId;
  final String targetLanguageTag;
  final AiContentCacheKind kind;

  /// Summary only.
  final String? aiServiceId;

  /// Translation only.
  final ArticleTranslationMode? translationMode;
  final String? translationProviderKind;
  final String? translationProviderServiceId;

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'articleId': articleId,
    'targetLanguageTag': targetLanguageTag,
    'kind': kind.name,
    'aiServiceId': aiServiceId,
    'translationMode': translationMode?.name,
    'translationProviderKind': translationProviderKind,
    'translationProviderServiceId': translationProviderServiceId,
  };
}

class AiContentCacheEntry {
  const AiContentCacheEntry({
    required this.key,
    required this.contentHash,
    required this.promptHash,
    required this.data,
    required this.updatedAt,
  });

  final AiContentCacheKey key;
  final String contentHash;
  final String? promptHash;
  final String data;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'key': key.toJson(),
    'contentHash': contentHash,
    'promptHash': promptHash,
    'data': data,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static AiContentCacheEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = json.cast<String, Object?>();
    final rawKey = map['key'];
    if (rawKey is! Map) return null;
    final keyMap = rawKey.cast<String, Object?>();

    final rawKind = keyMap['kind'];
    final kindName = rawKind is String ? rawKind.trim() : '';
    final kind = AiContentCacheKind.values.where((k) => k.name == kindName);
    if (kind.isEmpty) return null;

    final accountId = (keyMap['accountId'] as String?)?.trim() ?? '';
    final articleIdNum = keyMap['articleId'];
    final articleId = articleIdNum is num && articleIdNum.isFinite
        ? articleIdNum.toInt()
        : null;
    final targetLanguageTag =
        (keyMap['targetLanguageTag'] as String?)?.trim() ?? '';
    if (accountId.isEmpty || articleId == null || targetLanguageTag.isEmpty) {
      return null;
    }

    AiContentCacheKey key;
    if (kind.first == AiContentCacheKind.summary) {
      final aiServiceId = (keyMap['aiServiceId'] as String?)?.trim() ?? '';
      if (aiServiceId.isEmpty) return null;
      key = AiContentCacheKey.summary(
        accountId: accountId,
        articleId: articleId,
        targetLanguageTag: targetLanguageTag,
        aiServiceId: aiServiceId,
      );
    } else {
      final modeName = (keyMap['translationMode'] as String?)?.trim() ?? '';
      final mode = ArticleTranslationMode.values.where(
        (m) => m.name == modeName,
      );
      if (mode.isEmpty) return null;
      final providerKind =
          (keyMap['translationProviderKind'] as String?)?.trim() ?? '';
      final providerServiceId =
          (keyMap['translationProviderServiceId'] as String?)?.trim();
      if (providerKind.isEmpty) return null;
      key = AiContentCacheKey.translation(
        accountId: accountId,
        articleId: articleId,
        targetLanguageTag: targetLanguageTag,
        translationMode: mode.first,
        translationProviderKind: providerKind,
        translationProviderServiceId: providerServiceId,
      );
    }

    final contentHash = (map['contentHash'] as String?)?.trim() ?? '';
    if (contentHash.isEmpty) return null;

    final promptHash = (map['promptHash'] as String?)?.trim();
    final data = map['data'] is String ? map['data'] as String : null;
    if (data == null) return null;

    final rawUpdatedAt = map['updatedAt'];
    final updatedAt = rawUpdatedAt is String
        ? DateTime.tryParse(rawUpdatedAt)
        : null;

    return AiContentCacheEntry(
      key: key,
      contentHash: contentHash,
      promptHash: promptHash == null || promptHash.isEmpty ? null : promptHash,
      data: data,
      updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AiContentCacheStore {
  static const String _dirName = 'ai_cache';

  Future<AiContentCacheEntry?> read(AiContentCacheKey key) async {
    try {
      final f = await _fileForKey(key);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      return AiContentCacheEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AiContentCacheEntry entry) async {
    final f = await _fileForKey(entry.key);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(entry.toJson()));
  }

  Future<void> delete(AiContentCacheKey key) async {
    try {
      final f = await _fileForKey(key);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // ignore: best-effort cache cleanup
    }
  }

  Future<File> _fileForKey(AiContentCacheKey key) async {
    final dir = await PathManager.getCacheDir();
    final sub = Directory(p.join(dir.path, _dirName));
    final digest = sha256.convert(utf8.encode(jsonEncode(key.toJson())));
    final name = digest.toString().substring(0, 24);
    return File(p.join(sub.path, '$name.json'));
  }
}
