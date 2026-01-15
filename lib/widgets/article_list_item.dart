import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/article.dart';

class ArticleListItem extends StatelessWidget {
  const ArticleListItem({super.key, required this.article, required this.selected});

  final Article article;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final title = (article.title ?? '').trim();
    final subtitle = _formatTime(article.publishedAt);

    return ListTile(
      selected: selected,
      title: Text(
        title.isEmpty ? article.link : title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      leading: Icon(article.isRead ? Icons.article_outlined : Icons.article),
      trailing: article.isStarred ? const Icon(Icons.star) : null,
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    return DateFormat.yMMMd().add_Hm().format(local);
  }
}

