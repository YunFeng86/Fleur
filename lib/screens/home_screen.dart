import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/article_list_controller.dart';
import '../providers/core_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/unread_providers.dart';
import '../widgets/article_list.dart';
import '../widgets/reader_view.dart';
import '../widgets/sidebar.dart';
import '../utils/platform.dart';
import '../ui/global_nav.dart';
import '../ui/layout.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final totalWidth = MediaQuery.sizeOf(context).width;
    final useCompactTopBar =
        !isDesktop || globalNavModeForWidth(totalWidth) == GlobalNavMode.bottom;

    Future<void> refreshAll() async {
      Object? err;
      final feedId = ref.read(selectedFeedIdProvider);
      final categoryId = ref.read(selectedCategoryIdProvider);
      if (feedId != null) {
        final r = await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
        err = r.error;
      } else {
        final feeds = await ref.read(feedRepositoryProvider).getAll();
        final filtered = (categoryId == null)
            ? feeds
            : (categoryId < 0
                  ? feeds.where((f) => f.categoryId == null)
                  : feeds.where((f) => f.categoryId == categoryId));
        final batch = await ref
            .read(syncServiceProvider)
            .refreshFeedsSafe(filtered.map((f) => f.id));
        err = batch.firstError?.error;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
          ),
        ),
      );
    }

    Future<void> markAllRead() async {
      final selectedFeedId = ref.read(selectedFeedIdProvider);
      final selectedCategoryId = ref.read(selectedCategoryIdProvider);
      await ref
          .read(articleRepositoryProvider)
          .markAllRead(
            feedId: selectedFeedId,
            categoryId: selectedFeedId == null ? selectedCategoryId : null,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.done)));
    }

    Widget markAllReadFab() {
      return FloatingActionButton(
        onPressed: markAllRead,
        tooltip: l10n.markAllRead,
        child: const Icon(Icons.done_all),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _effectiveColumns(width);

        if (isDesktop) {
          final mode = desktopModeForWidth(width);
          return _buildDesktop(
            context,
            ref,
            l10n,
            mode,
            useCompactTopBar,
            refreshAll,
            markAllRead,
          );
        }

        // 1-column: mobile-style list + drawer, dedicated reader route.
        if (columns == 1) {
          final unreadOnly = ref.watch(unreadOnlyProvider);
          final starredOnly = ref.watch(starredOnlyProvider);
          final searchQuery = ref.watch(articleSearchQueryProvider).trim();
          return Scaffold(
            appBar: isDesktop
                ? null
                : AppBar(
                    title: Text(l10n.feeds),
                    actions: [
                      IconButton(
                        tooltip: l10n.refreshAll,
                        onPressed: refreshAll,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: l10n.starred,
                        onPressed: () {
                          final next = !starredOnly;
                          ref.read(starredOnlyProvider.notifier).state = next;
                          if (next) {
                            ref.read(selectedFeedIdProvider.notifier).state =
                                null;
                            ref
                                    .read(selectedCategoryIdProvider.notifier)
                                    .state =
                                null;
                            ref
                                    .read(articleSearchQueryProvider.notifier)
                                    .state =
                                '';
                          }
                        },
                        icon: Icon(
                          starredOnly ? Icons.star : Icons.star_border,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.search,
                        onPressed: () => context.go('/search'),
                        icon: const Icon(Icons.search),
                      ),
                      if (searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: l10n.delete,
                          onPressed: () =>
                              ref
                                      .read(articleSearchQueryProvider.notifier)
                                      .state =
                                  '',
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
                        onPressed: () =>
                            ref.read(unreadOnlyProvider.notifier).state =
                                !unreadOnly,
                        icon: Icon(
                          unreadOnly
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                        ),
                      ),
                    ],
                  ),
            drawer: isDesktop
                ? null
                : Drawer(
                    child: Sidebar(
                      onSelectFeed: (_) async {
                        await Navigator.of(context).maybePop(); // close drawer
                      },
                    ),
                  ),
            floatingActionButton: useCompactTopBar ? markAllReadFab() : null,
            body: ArticleList(selectedArticleId: selectedArticleId),
          );
        }

        // 2/3-column: desktop / tablet style with keyboard shortcuts.
        final shortcuts = <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyJ):
              const _NextArticleIntent(),
          const SingleActivator(LogicalKeyboardKey.keyK):
              const _PrevArticleIntent(),
          const SingleActivator(LogicalKeyboardKey.keyR):
              const _RefreshIntent(),
          const SingleActivator(LogicalKeyboardKey.keyU):
              const _ToggleUnreadIntent(),
          const SingleActivator(LogicalKeyboardKey.keyM):
              const _ToggleReadIntent(),
          const SingleActivator(LogicalKeyboardKey.keyS):
              const _ToggleStarIntent(),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              const _SearchIntent(),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              const _SearchIntent(),
        };

        return Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: {
              _NextArticleIntent: CallbackAction<_NextArticleIntent>(
                onInvoke: (intent) {
                  final list =
                      ref
                          .read(articleListControllerProvider)
                          .valueOrNull
                          ?.items ??
                      const [];
                  if (list.isEmpty) return null;
                  final idx = selectedArticleId == null
                      ? -1
                      : list.indexWhere((a) => a.id == selectedArticleId);
                  final next = list[(idx + 1).clamp(0, list.length - 1)];
                  context.go('/article/${next.id}');
                  return null;
                },
              ),
              _PrevArticleIntent: CallbackAction<_PrevArticleIntent>(
                onInvoke: (intent) {
                  final list =
                      ref
                          .read(articleListControllerProvider)
                          .valueOrNull
                          ?.items ??
                      const [];
                  if (list.isEmpty) return null;
                  final idx = selectedArticleId == null
                      ? 0
                      : list.indexWhere((a) => a.id == selectedArticleId);
                  final prev = list[(idx - 1).clamp(0, list.length - 1)];
                  context.go('/article/${prev.id}');
                  return null;
                },
              ),
              _RefreshIntent: CallbackAction<_RefreshIntent>(
                onInvoke: (intent) async {
                  final feedId = ref.read(selectedFeedIdProvider);
                  final categoryId = ref.read(selectedCategoryIdProvider);
                  if (feedId != null) {
                    await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
                  } else if (categoryId != null) {
                    final feeds = await ref
                        .read(feedRepositoryProvider)
                        .getAll();
                    final filtered = categoryId < 0
                        ? feeds.where((f) => f.categoryId == null)
                        : feeds.where((f) => f.categoryId == categoryId);
                    await ref
                        .read(syncServiceProvider)
                        .refreshFeedsSafe(filtered.map((f) => f.id));
                  } else {
                    final feeds = await ref
                        .read(feedRepositoryProvider)
                        .getAll();
                    await ref
                        .read(syncServiceProvider)
                        .refreshFeedsSafe(feeds.map((f) => f.id));
                  }
                  return null;
                },
              ),
              _ToggleUnreadIntent: CallbackAction<_ToggleUnreadIntent>(
                onInvoke: (intent) {
                  final cur = ref.read(unreadOnlyProvider);
                  ref.read(unreadOnlyProvider.notifier).state = !cur;
                  return null;
                },
              ),
              _ToggleReadIntent: CallbackAction<_ToggleReadIntent>(
                onInvoke: (intent) async {
                  if (selectedArticleId == null) return null;
                  final a = await ref
                      .read(articleRepositoryProvider)
                      .getById(selectedArticleId!);
                  if (a == null) return null;
                  await ref
                      .read(articleRepositoryProvider)
                      .markRead(selectedArticleId!, !a.isRead);
                  return null;
                },
              ),
              _ToggleStarIntent: CallbackAction<_ToggleStarIntent>(
                onInvoke: (intent) async {
                  if (selectedArticleId == null) return null;
                  await ref
                      .read(articleRepositoryProvider)
                      .toggleStar(selectedArticleId!);
                  return null;
                },
              ),
              _SearchIntent: CallbackAction<_SearchIntent>(
                onInvoke: (intent) {
                  context.go('/search');
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                appBar: useCompactTopBar
                    ? AppBar(
                        title: Text(l10n.feeds),
                        actions: [
                          IconButton(
                            tooltip: l10n.refreshAll,
                            onPressed: refreshAll,
                            icon: const Icon(Icons.refresh),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final unreadOnly = ref.watch(unreadOnlyProvider);
                              return IconButton(
                                tooltip: unreadOnly
                                    ? l10n.showAll
                                    : l10n.unreadOnly,
                                onPressed: () =>
                                    ref
                                            .read(unreadOnlyProvider.notifier)
                                            .state =
                                        !unreadOnly,
                                icon: Icon(
                                  unreadOnly
                                      ? Icons.filter_alt
                                      : Icons.filter_alt_outlined,
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : null,
                floatingActionButton: useCompactTopBar
                    ? markAllReadFab()
                    : null,
                drawer: (!isDesktop && columns == 2)
                    ? Drawer(
                        child: Sidebar(
                          onSelectFeed: (_) async {
                            await Navigator.of(
                              context,
                            ).maybePop(); // close drawer
                          },
                        ),
                      )
                    : null,
                body: Row(
                  children: [
                    if (columns == 3) ...[
                      SizedBox(
                        width: 280,
                        child: Sidebar(
                          onSelectFeed: (_) {
                            if (selectedArticleId != null) context.go('/');
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    SizedBox(
                      width: 420,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  if (!useCompactTopBar)
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final l10n = AppLocalizations.of(
                                          context,
                                        )!;
                                        final unreadOnly = ref.watch(
                                          unreadOnlyProvider,
                                        );
                                        return FilterChip(
                                          selected: unreadOnly,
                                          label: Text(l10n.unread),
                                          onSelected: (v) =>
                                              ref
                                                      .read(
                                                        unreadOnlyProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  v,
                                        );
                                      },
                                    ),
                                  const Spacer(),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final starredOnly = ref.watch(
                                        starredOnlyProvider,
                                      );
                                      return IconButton(
                                        tooltip: l10n.starred,
                                        onPressed: () {
                                          final next = !starredOnly;
                                          ref
                                                  .read(
                                                    starredOnlyProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              next;
                                          if (next) {
                                            ref
                                                    .read(
                                                      selectedFeedIdProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                null;
                                            ref
                                                    .read(
                                                      selectedCategoryIdProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                null;
                                            ref
                                                    .read(
                                                      articleSearchQueryProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                '';
                                          }
                                        },
                                        icon: Icon(
                                          starredOnly
                                              ? Icons.star
                                              : Icons.star_border,
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: l10n.search,
                                    onPressed: () => context.go('/search'),
                                    icon: const Icon(Icons.search),
                                  ),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final q = ref
                                          .watch(articleSearchQueryProvider)
                                          .trim();
                                      if (q.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        tooltip: l10n.delete,
                                        onPressed: () =>
                                            ref
                                                    .read(
                                                      articleSearchQueryProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                '',
                                        icon: const Icon(Icons.clear),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ArticleList(
                              selectedArticleId: selectedArticleId,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: selectedArticleId == null
                          ? Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              alignment: Alignment.center,
                              child: Text(l10n.selectAnArticle),
                            )
                          : ReaderView(
                              articleId: selectedArticleId!,
                              embedded: true,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    DesktopPaneMode mode,
    bool useCompactTopBar,
    Future<void> Function() refreshAll,
    Future<void> Function() markAllRead,
  ) {
    // Desktop keyboard shortcuts stay enabled across all layouts.
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyJ):
          const _NextArticleIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK):
          const _PrevArticleIntent(),
      const SingleActivator(LogicalKeyboardKey.keyR): const _RefreshIntent(),
      const SingleActivator(LogicalKeyboardKey.keyU):
          const _ToggleUnreadIntent(),
      const SingleActivator(LogicalKeyboardKey.keyM): const _ToggleReadIntent(),
      const SingleActivator(LogicalKeyboardKey.keyS): const _ToggleStarIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const _SearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const _SearchIntent(),
    };

    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    Widget listPane({double? width}) {
      final pane = Column(
        children: [
          Expanded(child: ArticleList(selectedArticleId: selectedArticleId)),
        ],
      );

      if (width == null) return pane;
      return SizedBox(width: width, child: pane);
    }

    Widget readerPane({required bool embedded}) {
      if (selectedArticleId == null) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          alignment: Alignment.center,
          child: Text(l10n.selectAnArticle),
        );
      }
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: ReaderView(articleId: selectedArticleId!, embedded: embedded),
      );
    }

    final body = switch (mode) {
      DesktopPaneMode.threePane => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sidebarVisible) ...[
            SizedBox(
              width: kDesktopSidebarWidth,
              child: Sidebar(
                onSelectFeed: (_) {
                  if (selectedArticleId != null) context.go('/');
                },
              ),
            ),
          ],
          listPane(width: kDesktopListWidth),
          Expanded(child: readerPane(embedded: true)),
        ],
      ),
      DesktopPaneMode.splitListReader => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          listPane(width: kDesktopListWidth),
          Expanded(child: readerPane(embedded: true)),
        ],
      ),
      DesktopPaneMode.listOnly => listPane(),
    };

    final content = Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _NextArticleIntent: CallbackAction<_NextArticleIntent>(
            onInvoke: (intent) {
              final list =
                  ref.read(articleListControllerProvider).valueOrNull?.items ??
                  const [];
              if (list.isEmpty) return null;
              final idx = selectedArticleId == null
                  ? -1
                  : list.indexWhere((a) => a.id == selectedArticleId);
              final next = list[(idx + 1).clamp(0, list.length - 1)];
              context.go('/article/${next.id}');
              return null;
            },
          ),
          _PrevArticleIntent: CallbackAction<_PrevArticleIntent>(
            onInvoke: (intent) {
              final list =
                  ref.read(articleListControllerProvider).valueOrNull?.items ??
                  const [];
              if (list.isEmpty) return null;
              final idx = selectedArticleId == null
                  ? 0
                  : list.indexWhere((a) => a.id == selectedArticleId);
              final prev = list[(idx - 1).clamp(0, list.length - 1)];
              context.go('/article/${prev.id}');
              return null;
            },
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (intent) async {
              final feedId = ref.read(selectedFeedIdProvider);
              final categoryId = ref.read(selectedCategoryIdProvider);
              if (feedId != null) {
                await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
              } else if (categoryId != null) {
                final feeds = await ref.read(feedRepositoryProvider).getAll();
                final filtered = categoryId < 0
                    ? feeds.where((f) => f.categoryId == null)
                    : feeds.where((f) => f.categoryId == categoryId);
                await ref
                    .read(syncServiceProvider)
                    .refreshFeedsSafe(filtered.map((f) => f.id));
              } else {
                final feeds = await ref.read(feedRepositoryProvider).getAll();
                await ref
                    .read(syncServiceProvider)
                    .refreshFeedsSafe(feeds.map((f) => f.id));
              }
              return null;
            },
          ),
          _ToggleUnreadIntent: CallbackAction<_ToggleUnreadIntent>(
            onInvoke: (intent) {
              final cur = ref.read(unreadOnlyProvider);
              ref.read(unreadOnlyProvider.notifier).state = !cur;
              return null;
            },
          ),
          _ToggleReadIntent: CallbackAction<_ToggleReadIntent>(
            onInvoke: (intent) async {
              if (selectedArticleId == null) return null;
              final a = await ref
                  .read(articleRepositoryProvider)
                  .getById(selectedArticleId!);
              if (a == null) return null;
              await ref
                  .read(articleRepositoryProvider)
                  .markRead(selectedArticleId!, !a.isRead);
              return null;
            },
          ),
          _ToggleStarIntent: CallbackAction<_ToggleStarIntent>(
            onInvoke: (intent) async {
              if (selectedArticleId == null) return null;
              await ref
                  .read(articleRepositoryProvider)
                  .toggleStar(selectedArticleId!);
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (intent) {
              context.go('/search');
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: body),
      ),
    );

    if (!useCompactTopBar) return content;

    final drawerEnabled = sidebarVisible && desktopSidebarInDrawer(mode);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feeds),
        actions: [
          IconButton(
            tooltip: l10n.refreshAll,
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadOnly = ref.watch(unreadOnlyProvider);
              return IconButton(
                tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
                onPressed: () =>
                    ref.read(unreadOnlyProvider.notifier).state = !unreadOnly,
                icon: Icon(
                  unreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: markAllRead,
        tooltip: l10n.markAllRead,
        child: const Icon(Icons.done_all),
      ),
      drawer: drawerEnabled
          ? Drawer(
              child: Sidebar(
                onSelectFeed: (_) async {
                  await Navigator.of(context).maybePop();
                },
              ),
            )
          : null,
      body: content,
    );
  }
}

class _NextArticleIntent extends Intent {
  const _NextArticleIntent();
}

class _PrevArticleIntent extends Intent {
  const _PrevArticleIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _ToggleUnreadIntent extends Intent {
  const _ToggleUnreadIntent();
}

class _ToggleReadIntent extends Intent {
  const _ToggleReadIntent();
}

class _ToggleStarIntent extends Intent {
  const _ToggleStarIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

int _effectiveColumns(double width) {
  // Non-desktop: classic M3-ish breakpoints.
  const mobileThreshold = 600.0;
  const largeThreshold = 1200.0;
  return width < mobileThreshold ? 1 : (width < largeThreshold ? 2 : 3);
}
