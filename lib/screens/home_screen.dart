import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../providers/backend_capabilities_provider.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../theme/fleur_icons.dart';
import '../ui/actions/subscription_object_menus.dart';
import '../ui/app_drawer_scope.dart';
import '../ui/hero_tags.dart';
import '../ui/home/home_scene_commands.dart';
import '../ui/home/home_scene_panes.dart';
import '../ui/home/home_scene_shortcuts.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';
import '../utils/platform.dart';
import '../widgets/fleur_capsule_button_group.dart';
import '../widgets/outbox_status_action.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Desktop stays chrome-less here; future shell controls live outside the
    // page instead of as an in-page AppBar.
    final useCompactTopBar = !isDesktop;
    final showSyncCapsule = LayoutSpec.fromContext(context).hasInlineSidebar;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final showRootRefresh = SubscriptionObjectMenus.showsRootRefresh(
      capabilities,
    );
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final refreshActionLabel = resolveHomeRefreshIntent(
      capabilities: capabilities,
      syncSemantics: syncSemantics,
      selectedFeedId: selectedFeedId,
      selectedCategoryId: selectedCategoryId,
    ).label(l10n);
    final commands = HomeSceneCommands(
      context: context,
      ref: ref,
      selectedArticleId: selectedArticleId,
    );

    Future<void> refreshAll() async {
      final outcome = await commands.refreshAll();
      final err = outcome.batch.firstError?.error;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null
                ? outcome.successLabel(l10n)
                : l10n.errorMessage(err.toString()),
          ),
        ),
      );
    }

    Future<void> markAllRead() async {
      await commands.markAllRead();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.done)));
    }

    Widget markAllReadFab() {
      return FloatingActionButton(
        onPressed: markAllRead,
        tooltip: l10n.markAllRead,
        child: const Icon(FleurIcons.markAllRead),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final listWidth = ref
            .watch(workspaceListWidthProvider)
            .clamp(kMinWorkspaceListWidth, kMaxWorkspaceListWidth)
            .toDouble();
        final columns = homeColumnsForWidth(width);

        if (isDesktop) {
          final mode = desktopModeForWidth(width, listWidth: listWidth);
          return _buildDesktop(
            context,
            ref,
            l10n,
            mode,
            useCompactTopBar,
            commands,
            refreshAll,
            showRootRefresh,
            refreshActionLabel,
            markAllRead,
            listWidth,
          );
        }

        // 1-column: mobile-style list + drawer, dedicated reader route.
        if (columns == 1) {
          final unreadOnly = ref.watch(unreadOnlyProvider);
          return Scaffold(
            appBar: AppBar(
              leading: AppDrawerScope.drawerLeading(context),
              title: Text(l10n.feeds),
              actions: [
                if (showRootRefresh)
                  IconButton(
                    tooltip: refreshActionLabel,
                    onPressed: refreshAll,
                    icon: const Icon(FleurIcons.refresh),
                  ),
                // The mobile AppBar stays focused on feed-only actions while
                // shell-level navigation lives in the drawer/sidebar model.
                IconButton(
                  tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
                  onPressed: commands.toggleUnreadOnly,
                  icon: Icon(
                    unreadOnly ? FleurIcons.filterActive : FleurIcons.filter,
                  ),
                ),
                const OutboxStatusAction(),
              ],
            ),
            floatingActionButton: useCompactTopBar ? markAllReadFab() : null,
            body: HomeArticleListPane(
              selectedArticleId: selectedArticleId,
              showSyncCapsule: showSyncCapsule,
            ),
          );
        }

        // 2/3-column: tablet style with shared keyboard shortcuts.
        return HomeSceneShortcuts(
          commands: commands,
          child: Scaffold(
            appBar: useCompactTopBar
                ? AppBar(
                    leading: AppDrawerScope.drawerLeading(context),
                    title: Text(l10n.feeds),
                    actions: [
                      if (showRootRefresh)
                        IconButton(
                          tooltip: refreshActionLabel,
                          onPressed: refreshAll,
                          icon: const Icon(FleurIcons.refresh),
                        ),
                      Consumer(
                        builder: (context, ref, _) {
                          final unreadOnly = ref.watch(unreadOnlyProvider);
                          return IconButton(
                            tooltip: unreadOnly
                                ? l10n.showAll
                                : l10n.unreadOnly,
                            onPressed: commands.toggleUnreadOnly,
                            icon: Icon(
                              unreadOnly
                                  ? FleurIcons.filterActive
                                  : FleurIcons.filter,
                            ),
                          );
                        },
                      ),
                      const OutboxStatusAction(),
                    ],
                  )
                : null,
            floatingActionButton: useCompactTopBar ? markAllReadFab() : null,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _workspacePanes(
                context: context,
                ref: ref,
                listWidth: kHomeListWidth,
                selectedArticleId: selectedArticleId,
                showSyncCapsule: showSyncCapsule,
                enableSplitHandle: false,
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
    HomeSceneCommands commands,
    Future<void> Function() refreshAll,
    bool showRootRefresh,
    String refreshActionLabel,
    Future<void> Function() markAllRead,
    double listWidth,
  ) {
    final showSyncCapsule = LayoutSpec.fromContext(context).hasInlineSidebar;
    final topBar = _HomeArticleListToolbar(
      showRefresh: showRootRefresh,
      refreshTooltip: refreshActionLabel,
      onRefresh: refreshAll,
      onToggleUnreadOnly: commands.toggleUnreadOnly,
      onMarkAllRead: markAllRead,
    );

    final body = switch (mode) {
      DesktopPaneMode.threePane || DesktopPaneMode.splitListReader => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _workspacePanes(
          context: context,
          ref: ref,
          listWidth: listWidth,
          heroTag: kHeroArticleListPane,
          selectedArticleId: selectedArticleId,
          showSyncCapsule: showSyncCapsule,
          topBar: topBar,
          enableSplitHandle: true,
        ),
      ),
      DesktopPaneMode.listOnly => HomeArticleListPane(
        selectedArticleId: selectedArticleId,
        showSyncCapsule: showSyncCapsule,
        topBar: topBar,
      ),
    };

    final content = HomeSceneShortcuts(commands: commands, child: body);

    if (!useCompactTopBar) return content;

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawerScope.drawerLeading(context),
        title: Text(l10n.feeds),
        actions: [
          if (showRootRefresh)
            IconButton(
              tooltip: refreshActionLabel,
              onPressed: refreshAll,
              icon: const Icon(FleurIcons.refresh),
            ),
          Consumer(
            builder: (context, ref, _) {
              final unreadOnly = ref.watch(unreadOnlyProvider);
              return IconButton(
                tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
                onPressed: commands.toggleUnreadOnly,
                icon: Icon(
                  unreadOnly ? FleurIcons.filterActive : FleurIcons.filter,
                ),
              );
            },
          ),
          const OutboxStatusAction(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: markAllRead,
        tooltip: l10n.markAllRead,
        child: const Icon(FleurIcons.markAllRead),
      ),
      body: content,
    );
  }

  List<Widget> _workspacePanes({
    required BuildContext context,
    required WidgetRef ref,
    required double listWidth,
    required int? selectedArticleId,
    required bool showSyncCapsule,
    required bool enableSplitHandle,
    Object? heroTag,
    Widget? topBar,
  }) {
    if (selectedArticleId == null) {
      return [
        Expanded(
          child: HomeArticleListPane(
            heroTag: heroTag,
            selectedArticleId: selectedArticleId,
            showSyncCapsule: showSyncCapsule,
            topBar: topBar,
          ),
        ),
      ];
    }

    return [
      HomeArticleListPane(
        width: listWidth,
        heroTag: heroTag,
        selectedArticleId: selectedArticleId,
        showSyncCapsule: showSyncCapsule,
        topBar: topBar,
      ),
      if (enableSplitHandle)
        WorkspaceSplitHandle(
          key: const Key('workspace_list_split_handle'),
          onDragDelta: (delta) {
            final spec = LayoutSpec.fromContext(context);
            final maxForWindow =
                (spec.contentWidth - kMinReadingWidth - kPaneGap)
                    .clamp(kMinWorkspaceListWidth, kMaxWorkspaceListWidth)
                    .toDouble();
            final notifier = ref.read(workspaceListWidthProvider.notifier);
            notifier.state = (notifier.state + delta)
                .clamp(kMinWorkspaceListWidth, maxForWindow)
                .toDouble();
          },
        ),
      Expanded(child: HomeReaderPane(articleId: selectedArticleId)),
    ];
  }
}

class _HomeArticleListToolbar extends ConsumerWidget {
  const _HomeArticleListToolbar({
    required this.showRefresh,
    required this.refreshTooltip,
    required this.onRefresh,
    required this.onToggleUnreadOnly,
    required this.onMarkAllRead,
  });

  final bool showRefresh;
  final String refreshTooltip;
  final Future<void> Function() onRefresh;
  final VoidCallback onToggleUnreadOnly;
  final Future<void> Function() onMarkAllRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unreadOnly = ref.watch(unreadOnlyProvider);
    final title = _scopeTitle(ref, l10n);
    final actionCount = (showRefresh ? 1 : 0) + 2;
    final trailingWidth = actionCount * kShellControlSize + 2;

    return WorkspaceHeader(
      title: title,
      trailingWidth: trailingWidth,
      trailing: FleurCapsuleButtonGroup(
        key: const Key('home_scope_actions'),
        children: [
          if (showRefresh)
            FleurCapsuleIconButton(
              key: const Key('scope_refresh_button'),
              tooltip: refreshTooltip,
              onPressed: onRefresh,
              icon: FleurIcons.refresh,
            ),
          FleurCapsuleIconButton(
            key: const Key('scope_unread_filter_button'),
            tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
            onPressed: onToggleUnreadOnly,
            selected: unreadOnly,
            icon: unreadOnly ? FleurIcons.filterActive : FleurIcons.filter,
          ),
          FleurCapsuleIconButton(
            key: const Key('scope_mark_all_read_button'),
            tooltip: l10n.markAllRead,
            onPressed: onMarkAllRead,
            icon: FleurIcons.markAllRead,
          ),
        ],
      ),
    );
  }

  String _scopeTitle(WidgetRef ref, AppLocalizations l10n) {
    final starredOnly = ref.watch(starredOnlyProvider);
    if (starredOnly) return l10n.starred;

    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    if (readLaterOnly) return l10n.readLater;

    final tagId = ref.watch(selectedTagIdProvider);
    if (tagId != null) {
      final tags = ref.watch(tagsProvider).valueOrNull;
      if (tags != null) {
        for (final tag in tags) {
          if (tag.id == tagId) return tag.name;
        }
      }
      return l10n.feeds;
    }

    final feedId = ref.watch(selectedFeedIdProvider);
    if (feedId != null) {
      final feed = ref.watch(feedProvider(feedId)).valueOrNull;
      if (feed != null) {
        final userTitle = feed.userTitle?.trim();
        if (userTitle != null && userTitle.isNotEmpty) return userTitle;

        final title = feed.title?.trim();
        if (title != null && title.isNotEmpty) return title;

        return feed.url;
      }
      return l10n.feeds;
    }

    final categoryId = ref.watch(selectedCategoryIdProvider);
    if (categoryId != null) {
      final category = ref.watch(categoryProvider(categoryId)).valueOrNull;
      return category?.name ?? l10n.feeds;
    }

    return l10n.all;
  }
}
