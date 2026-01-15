import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/query_providers.dart';
import 'article_list_item.dart';

class ArticleList extends ConsumerWidget {
  const ArticleList({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedId = ref.watch(selectedFeedIdProvider);
    final articles = ref.watch(articlesProvider(feedId));

    return articles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No articles'));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final a = items[index];
            return InkWell(
              onTap: () => context.go('/article/${a.id}'),
              child: ArticleListItem(article: a, selected: a.id == selectedArticleId),
            );
          },
        );
      },
    );
  }
}
