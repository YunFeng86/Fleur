import 'package:flutter/foundation.dart';

enum ReaderDisplayMode { source, translation }

@immutable
class ReaderTypographySettings {
  const ReaderTypographySettings({
    required this.fontSize,
    required this.minimumFontSize,
    required this.lineHeight,
    required this.horizontalPadding,
  });

  final double fontSize;
  final double minimumFontSize;
  final double lineHeight;
  final double horizontalPadding;

  @override
  bool operator ==(Object other) {
    return other is ReaderTypographySettings &&
        fontSize == other.fontSize &&
        minimumFontSize == other.minimumFontSize &&
        lineHeight == other.lineHeight &&
        horizontalPadding == other.horizontalPadding;
  }

  @override
  int get hashCode =>
      Object.hash(fontSize, minimumFontSize, lineHeight, horizontalPadding);
}

@immutable
class ReaderDocumentKey {
  const ReaderDocumentKey({
    required this.articleId,
    required this.sourceRevision,
    required this.baseUrl,
    required this.displayMode,
    required this.translationRevision,
    required this.typography,
  });

  final String articleId;
  final String sourceRevision;
  final String baseUrl;
  final ReaderDisplayMode displayMode;
  final String? translationRevision;
  final ReaderTypographySettings typography;

  @override
  bool operator ==(Object other) {
    return other is ReaderDocumentKey &&
        articleId == other.articleId &&
        sourceRevision == other.sourceRevision &&
        baseUrl == other.baseUrl &&
        displayMode == other.displayMode &&
        translationRevision == other.translationRevision &&
        typography == other.typography;
  }

  @override
  int get hashCode => Object.hash(
    articleId,
    sourceRevision,
    baseUrl,
    displayMode,
    translationRevision,
    typography,
  );

  @override
  String toString() {
    return 'ReaderDocumentKey('
        'articleId: $articleId, '
        'sourceRevision: $sourceRevision, '
        'baseUrl: $baseUrl, '
        'displayMode: ${displayMode.name}, '
        'translationRevision: $translationRevision)';
  }
}

@immutable
class ReaderChunkRange {
  const ReaderChunkRange({
    required this.index,
    required this.start,
    required this.end,
    required this.estimatedBytes,
    required this.stableAnchor,
  });

  final int index;
  final int start;
  final int end;
  final int estimatedBytes;
  final String stableAnchor;
}

@immutable
class ReaderDocumentSnapshot {
  const ReaderDocumentSnapshot({
    required this.documentKey,
    required this.articleId,
    required this.displayHtml,
    required this.contentByteSize,
    required this.chunks,
    required this.primaryLanguage,
    required this.renderRevision,
    required this.isChunked,
    required this.contentHash,
  });

  final ReaderDocumentKey documentKey;
  final String articleId;
  final String displayHtml;
  final int contentByteSize;
  final List<ReaderChunkRange> chunks;
  final String? primaryLanguage;
  final int renderRevision;
  final bool isChunked;
  final String contentHash;
}

@immutable
class ReaderDocumentRequest {
  const ReaderDocumentRequest({
    required this.articleId,
    required this.sourceRevision,
    required this.rawHtml,
    required this.baseUrl,
    required this.displayMode,
    required this.typography,
    this.translationRevision,
    this.primaryLanguage,
  });

  final String articleId;
  final String sourceRevision;
  final String rawHtml;
  final String baseUrl;
  final ReaderDisplayMode displayMode;
  final ReaderTypographySettings typography;
  final String? translationRevision;
  final String? primaryLanguage;

  ReaderDocumentKey get documentKey {
    return ReaderDocumentKey(
      articleId: articleId,
      sourceRevision: sourceRevision,
      baseUrl: baseUrl,
      displayMode: displayMode,
      translationRevision: translationRevision,
      typography: typography,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderDocumentRequest &&
        articleId == other.articleId &&
        sourceRevision == other.sourceRevision &&
        baseUrl == other.baseUrl &&
        displayMode == other.displayMode &&
        typography == other.typography &&
        translationRevision == other.translationRevision &&
        primaryLanguage == other.primaryLanguage;
  }

  @override
  int get hashCode => Object.hash(
    articleId,
    sourceRevision,
    baseUrl,
    displayMode,
    typography,
    translationRevision,
    primaryLanguage,
  );
}
