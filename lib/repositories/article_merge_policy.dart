import '../models/article.dart';
import '../utils/content_hash.dart';
import '../utils/link_normalizer.dart';

class ArticleIngestionPlan {
  const ArticleIngestionPlan({
    required this.normalizedLinks,
    required this.remoteIds,
  });

  final List<String> normalizedLinks;
  final List<String> remoteIds;
}

class ArticleMergeLookup {
  ArticleMergeLookup(Iterable<Article> existingArticles) {
    for (final article in existingArticles) {
      final remoteId = article.remoteId;
      if (remoteId != null && remoteId.isNotEmpty) {
        _byRemoteId[remoteId] = article;
      }
      _byLink[article.link] = article;
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
    final normalizedLinks = <String>[];
    final remoteIds = <String>[];

    for (final article in incoming) {
      article.link = LinkNormalizer.normalize(article.link);
      normalizedLinks.add(article.link);

      final remoteId = article.remoteId;
      if (remoteId != null && remoteId.trim().isNotEmpty) {
        remoteIds.add(remoteId);
      }

      article.contentHash = preserveUserState
          ? ContentHash.compute(article.contentHtml)
          : null;
    }

    return ArticleIngestionPlan(
      normalizedLinks: normalizedLinks,
      remoteIds: remoteIds,
    );
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
