import 'package:flutter/foundation.dart';

enum ArticleScopeType { all, starred, readLater, feed, category, tag }

@immutable
class ArticleScope {
  const ArticleScope._(this.type, [this.id]);

  const ArticleScope.feed(int id) : this._(ArticleScopeType.feed, id);

  const ArticleScope.category(int id) : this._(ArticleScopeType.category, id);

  const ArticleScope.tag(int id) : this._(ArticleScopeType.tag, id);

  static const all = ArticleScope._(ArticleScopeType.all);
  static const starred = ArticleScope._(ArticleScopeType.starred);
  static const readLater = ArticleScope._(ArticleScopeType.readLater);

  final ArticleScopeType type;
  final int? id;

  int? get feedId => type == ArticleScopeType.feed ? id : null;
  int? get categoryId => type == ArticleScopeType.category ? id : null;
  int? get tagId => type == ArticleScopeType.tag ? id : null;
  bool get starredOnly => type == ArticleScopeType.starred;
  bool get readLaterOnly => type == ArticleScopeType.readLater;
  bool get isSavedScope => starredOnly || readLaterOnly;

  @override
  bool operator ==(Object other) {
    return other is ArticleScope && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() {
    return switch (type) {
      ArticleScopeType.all => 'ArticleScope.all',
      ArticleScopeType.starred => 'ArticleScope.starred',
      ArticleScopeType.readLater => 'ArticleScope.readLater',
      ArticleScopeType.feed => 'ArticleScope.feed($id)',
      ArticleScopeType.category => 'ArticleScope.category($id)',
      ArticleScopeType.tag => 'ArticleScope.tag($id)',
    };
  }
}
