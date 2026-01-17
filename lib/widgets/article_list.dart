import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_reader/l10n/app_localizations.dart';

import '../providers/article_list_controller.dart';
import '../providers/repository_providers.dart';
import '../providers/unread_providers.dart';
import '../ui/layout.dart';
import '../utils/platform.dart';
import 'article_list_item.dart';

class ArticleList extends ConsumerStatefulWidget {
  const ArticleList({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  ConsumerState<ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends ConsumerState<ArticleList> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()
      ..addListener(() {
        final pos = _controller.position;
        if (pos.maxScrollExtent <= 0) return;
        if (pos.pixels >= pos.maxScrollExtent - 600) {
          ref.read(articleListControllerProvider.notifier).loadMore();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadOnly = ref.watch(unreadOnlyProvider);
    final state = ref.watch(articleListControllerProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (data) {
        final items = data.items;
        if (items.isEmpty) {
          return Center(
            child: Text(unreadOnly ? l10n.noUnreadArticles : l10n.noArticles),
          );
        }

        final narrow = MediaQuery.sizeOf(context).width < 600;

        return ListView.separated(
          controller: _controller,
          itemCount: items.length + (data.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: data.isLoadingMore
                      ? const CircularProgressIndicator()
                      : Text(l10n.scrollToLoadMore),
                ),
              );
            }

            final a = items[index];
            final tile = ArticleListItem(
              article: a,
              selected: a.id == widget.selectedArticleId,
              onTap: () {
                final width = MediaQuery.sizeOf(context).width;

                final openAsSecondaryPage = isDesktop
                    ? !desktopReaderEmbedded(desktopModeForWidth(width))
                    : width < 600;

                if (openAsSecondaryPage) {
                  context.push('/article/${a.id}');
                } else {
                  context.go('/article/${a.id}');
                }
              },
            );

            Widget child = tile;

            if (narrow) {
              child = Dismissible(
                key: ValueKey(a.id),
                background: Container(
                  color: Colors.green.shade700,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    a.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                    color: Colors.white,
                  ),
                ),
                secondaryBackground: Container(
                  color: Colors.amber.shade800,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    a.isStarred ? Icons.star_border : Icons.star,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (direction) async {
                  final repo = ref.read(articleRepositoryProvider);
                  if (direction == DismissDirection.startToEnd) {
                    await repo.markRead(a.id, !a.isRead);
                  } else {
                    await repo.toggleStar(a.id);
                  }
                  return false; // keep item in list
                },
                child: child,
              );
            }

            return child;
          },
        );
      },
    );
  }
}
