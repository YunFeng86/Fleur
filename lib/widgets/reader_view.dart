import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../providers/reader_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';

class ReaderView extends ConsumerWidget {
  const ReaderView({super.key, required this.articleId, this.embedded = false});

  final int articleId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(fullTextControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Full text failed: ${next.error}')),
        );
      }
    });

    final a = ref.watch(articleProvider(articleId));
    final fullText = ref.watch(fullTextControllerProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (article) {
        if (article == null) return const Center(child: Text('Not found'));

        final html = (article.fullContentHtml ?? article.contentHtml ?? '').trim();
        final title = article.title?.trim().isNotEmpty == true ? article.title! : 'Reader';

        final hasFull = (article.fullContentHtml ?? '').trim().isNotEmpty;
        final actions = <Widget>[
          IconButton(
            tooltip: 'Full text',
            onPressed: (hasFull || fullText.isLoading)
                ? null
                : () => ref
                    .read(fullTextControllerProvider.notifier)
                    .fetch(articleId),
            icon: fullText.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chrome_reader_mode),
          ),
          IconButton(
            tooltip: article.isStarred ? 'Unstar' : 'Star',
            onPressed: () =>
                ref.read(articleRepositoryProvider).toggleStar(articleId),
            icon: Icon(article.isStarred ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: article.isRead ? 'Mark unread' : 'Mark read',
            onPressed: () =>
                ref.read(articleRepositoryProvider).markRead(articleId, !article.isRead),
            icon: Icon(
              article.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
            ),
          ),
        ];

        final content = html.isEmpty
            ? Center(child: Text(article.link))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                child: HtmlWidget(html),
              );

        if (!embedded) {
          return Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: content);
        }

        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
