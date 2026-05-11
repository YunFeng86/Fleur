import '../models/article.dart';
import '../utils/content_hash.dart';
import '../utils/link_normalizer.dart';

class ArticleIngestionPlan {
  const ArticleIngestionPlan({
    required this.linkLookupKeys,
    required this.remoteIds,
  });

  final List<String> linkLookupKeys;
  final List<String> remoteIds;
}

class ArticleMergeLookup {
  ArticleMergeLookup(Iterable<Article> existingArticles) {
    for (final article in existingArticles) {
      final remoteId = article.remoteId;
      if (remoteId != null && remoteId.isNotEmpty) {
        _byRemoteId[remoteId] = article;
      }
      _byLink[LinkNormalizer.normalize(article.link)] = article;
    }
  }

  final Map<String, Article> _byRemoteId = {};
  final Map<String, Article> _byLink = {};

  Article? findFor(Article incoming) {
    final remoteId = incoming.remoteId;
    if (remoteId != null && remoteId.isNotEmpty) {
      return _byRemoteId[remoteId] ?? _byLink[incoming.link];
    }
    return _byLink[incoming.link];
  }
}

class ArticleMergePolicy {
  const ArticleMergePolicy();

  ArticleIngestionPlan prepareIncoming(
    List<Article> incoming, {
    required bool preserveUserState,
  }) {
    final linkLookupKeys = <String>{};
    final remoteIds = <String>[];

    for (final article in incoming) {
      final rawLink = article.link;
      article.link = LinkNormalizer.normalize(article.link);
      linkLookupKeys.add(article.link);
      if (article.link.isNotEmpty) {
        // Compatibility with links written by the previous normalizer, which
        // accidentally persisted an empty fragment marker.
        linkLookupKeys.add('${article.link}#');
      }
      final legacyLink = _legacyEmptyFragmentLookupKey(rawLink);
      if (legacyLink.isNotEmpty) {
        linkLookupKeys.add(legacyLink);
      }

      final remoteId = article.remoteId;
      if (remoteId != null && remoteId.trim().isNotEmpty) {
        remoteIds.add(remoteId);
      }

      article.contentHash = preserveUserState
          ? ContentHash.compute(article.contentHtml)
          : null;
    }

    return ArticleIngestionPlan(
      linkLookupKeys: linkLookupKeys.toList(growable: false),
      remoteIds: remoteIds,
    );
  }

  static String _legacyEmptyFragmentLookupKey(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    return uri.replace(fragment: '').toString();
  }

  bool merge({
    required Article incoming,
    required Article? existing,
    required int feedId,
    required int? categoryId,
    required DateTime now,
    required bool preserveUserState,
  }) {
    incoming
      ..feedId = feedId
      ..categoryId = categoryId
      ..updatedAt = now
      ..fetchedAt = now;

    if (existing == null) {
      incoming.contentHash = preserveUserState
          ? incoming.contentHash ?? ''
          : null;
      if (incoming.publishedAt.millisecondsSinceEpoch == 0) {
        incoming.publishedAt = now.toUtc();
      }
      return true;
    }

    incoming.id = existing.id;
    if (preserveUserState) {
      final newHash = incoming.contentHash ?? '';
      if (existing.contentHash != newHash) {
        incoming
          ..contentHash = newHash
          ..isRead = false;
      } else {
        incoming
          ..isRead = existing.isRead
          ..contentHash = existing.contentHash;
      }
      incoming.isStarred = existing.isStarred;
    } else {
      incoming.contentHash = null;
    }

    incoming
      ..isReadLater = existing.isReadLater
      ..contentSource = existing.contentSource
      ..extractedContentHtml = existing.extractedContentHtml
      ..preferredContentView = existing.preferredContentView;

    if (incoming.contentHtml == null || incoming.contentHtml!.trim().isEmpty) {
      incoming.contentHtml = existing.contentHtml;
    }
    if (incoming.publishedAt.millisecondsSinceEpoch == 0) {
      incoming.publishedAt = existing.publishedAt;
    }

    return false;
  }
}
