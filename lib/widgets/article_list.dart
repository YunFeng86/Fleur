import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_reader/l10n/app_localizations.dart';

import '../providers/article_list_controller.dart';
import '../providers/app_settings_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../services/settings/app_settings.dart';
import '../ui/layout.dart';
import '../utils/platform.dart';
import '../models/article.dart';
import 'article_list_item.dart';

class ArticleList extends ConsumerStatefulWidget {
  const ArticleList({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  ConsumerState<ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends ConsumerState<ArticleList> {
  late final ScrollController _controller;

  // Cache to avoid recalculating entries on every build
  List<Article> _cachedItems = [];
  ArticleGroupMode _cachedGroupMode = ArticleGroupMode.none;
  List<_ArticleListEntry> _cachedEntries = [];

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

  List<_ArticleListEntry> _getEntries(
    List<Article> items,
    ArticleGroupMode groupMode,
  ) {
    // Only recalculate if items or groupMode changed
    if (items != _cachedItems || groupMode != _cachedGroupMode) {
      _cachedItems = items;
      _cachedGroupMode = groupMode;
      _cachedEntries = groupMode == ArticleGroupMode.day
          ? _buildDayGroupedEntries(items)
          : items.map<_ArticleListEntry>((a) => _ArticleEntry(a)).toList();
    }
    return _cachedEntries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadOnly = ref.watch(unreadOnlyProvider);
    final starredOnly = ref.watch(starredOnlyProvider);
    final searchQuery = ref.watch(articleSearchQueryProvider).trim();
    final state = ref.watch(articleListControllerProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final groupMode = settings?.articleGroupMode ?? ArticleGroupMode.none;

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (data) {
        final items = data.items;
        if (items.isEmpty) {
          Widget child;
          if (searchQuery.isNotEmpty || starredOnly) {
            child = Text(l10n.notFound);
          } else {
            child = Text(unreadOnly ? l10n.noUnreadArticles : l10n.noArticles);
          }
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            alignment: Alignment.center,
            child: child,
          );
        }

        final narrow = MediaQuery.sizeOf(context).width < 600;

        final entries = _getEntries(items, groupMode);

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: isDesktop,
            interactive: true,
            child: ListView.builder(
              controller: _controller,
              itemCount: entries.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= entries.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: data.isLoadingMore
                          ? const CircularProgressIndicator()
                          : Text(l10n.scrollToLoadMore),
                    ),
                  );
                }

                final entry = entries[index];
                if (entry is _HeaderEntry) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }

                final seed = (entry as _ArticleEntry).article;
                return Consumer(
                  builder: (context, ref, _) {
                    final live =
                        ref.watch(articleProvider(seed.id)).valueOrNull ?? seed;
                    Widget child = ArticleListItem(
                      article: live,
                      selected: live.id == widget.selectedArticleId,
                      onTap: () {
                        if (live.id == widget.selectedArticleId) {
                          context.go('/');
                          return;
                        }

                        final width = MediaQuery.sizeOf(context).width;

                        final openAsSecondaryPage = isDesktop
                            ? !desktopReaderEmbedded(desktopModeForWidth(width))
                            : width < 600;

                        if (openAsSecondaryPage) {
                          context.push('/article/${live.id}');
                        } else {
                          context.go('/article/${live.id}');
                        }
                      },
                    );

                    if (narrow) {
                      child = Dismissible(
                        key: ValueKey(live.id),
                        background: Container(
                          color: Colors.green.shade700,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            live.isRead
                                ? Icons.mark_email_unread
                                : Icons.mark_email_read,
                            color: Colors.white,
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.amber.shade800,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            live.isStarred ? Icons.star_border : Icons.star,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          final repo = ref.read(articleRepositoryProvider);
                          if (direction == DismissDirection.startToEnd) {
                            await repo.markRead(live.id, !live.isRead);
                          } else {
                            await repo.toggleStar(live.id);
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
            ),
          ),
        );
      },
    );
  }
}

sealed class _ArticleListEntry {}

class _HeaderEntry extends _ArticleListEntry {
  _HeaderEntry(this.title);
  final String title;
}

class _ArticleEntry extends _ArticleListEntry {
  _ArticleEntry(this.article);
  final Article article;
}

List<_ArticleListEntry> _buildDayGroupedEntries(List<Article> items) {
  final out = <_ArticleListEntry>[];
  DateTime? currentDay;
  for (final a in items) {
    final t = a.publishedAt.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      out.add(_HeaderEntry(DateFormat('yyyy/MM/dd').format(day)));
    }
    out.add(_ArticleEntry(a));
  }
  return out;
}
