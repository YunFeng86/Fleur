import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';

import '../../app/article_scope_routes.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/query_providers.dart';
import '../../providers/unread_providers.dart';
import '../../theme/fleur_icons.dart';
import '../design_system/design_system.dart';
import 'outbox_status_action.dart';
import '../app_drawer_scope.dart';
import 'article_reader_workspace_layout.dart';
import 'home_scene_commands.dart';
import 'home_scene_panes.dart';
import 'home_scene_shortcuts.dart';
import '../layout.dart';
import '../layout_spec.dart';
import '../shell_chrome_layout.dart';
import '../sidebar_layout.dart';
import '../workspace_layers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final layoutSpec = LayoutSpec.fromContext(context);
    final usesContentPageHeader =
        layoutSpec.shellChromeLayout.profile == ShellChromeProfile.contentOnly;
    final showSyncCapsule = layoutSpec.showsListSyncStatusCapsule;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final showRootRefresh = SubscriptionObjectMenus.showsRootRefresh(
      capabilities,
      syncSemantics,
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final listWidth = clampWorkspaceListWidth(
          ref.watch(workspaceListWidthProvider),
          width,
        );
        final arrangement = layoutSpec.resolveFeedArrangement(
          listWidth: kHomeListWidth,
          hasReader: selectedArticleId != null,
        );
        final articleId = selectedArticleId;
        if (articleId != null && arrangement.showsSecondaryReader) {
          final fallbackLocation = scopeLocation(
            ref.watch(currentArticleScopeProvider),
          );
          return HomeSceneShortcuts(
            commands: commands,
            child: HomeReaderPane(
              articleId: articleId,
              embedded: false,
              fallbackBackLocation: fallbackLocation,
            ),
          );
        }
        final topBar = usesContentPageHeader
            ? null
            : _HomeArticleListToolbar(
                showRefresh: showRootRefresh,
                refreshTooltip: refreshActionLabel,
                onRefresh: refreshAll,
                onToggleUnreadOnly: commands.toggleUnreadOnly,
                onMarkAllRead: markAllRead,
              );
        final content = HomeSceneShortcuts(
          commands: commands,
          child: _buildWorkspaceLayout(
            ref: ref,
            contentWidth: width,
            listWidth: listWidth,
            selectedArticleId: selectedArticleId,
            showSyncCapsule: showSyncCapsule,
            enableSplitHandle:
                selectedArticleId != null && arrangement.readerEmbedded,
            topBar: topBar,
          ),
        );
        if (!usesContentPageHeader) return content;

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
          floatingActionButton: FloatingActionButton(
            onPressed: markAllRead,
            tooltip: l10n.markAllRead,
            child: const Icon(FleurIcons.markAllRead),
          ),
          body: content,
        );
      },
    );
  }

  Widget _buildWorkspaceLayout({
    required WidgetRef ref,
    required double contentWidth,
    required double listWidth,
    required int? selectedArticleId,
    required bool showSyncCapsule,
    required bool enableSplitHandle,
    Widget? topBar,
  }) {
    return ArticleReaderWorkspaceLayout(
      selectedArticleId: selectedArticleId,
      contentWidth: contentWidth,
      listWidth: listWidth,
      listPane: HomeArticleListPane(
        selectedArticleId: selectedArticleId,
        showSyncCapsule: showSyncCapsule,
        topBar: topBar,
      ),
      readerPane: selectedArticleId == null
          ? null
          : HomeReaderPane(articleId: selectedArticleId),
      showSplitHandle: enableSplitHandle && selectedArticleId != null,
      onResizeList: enableSplitHandle
          ? (delta) {
              final notifier = ref.read(workspaceListWidthProvider.notifier);
              notifier.state = clampWorkspaceListWidth(
                notifier.state + delta,
                contentWidth,
              );
            }
          : null,
    );
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
    final title = _homeScopeTitle(ref, l10n);

    return WorkspaceHeader(
      title: title,
      trailingWidth: _homeScopeActionsWidth(showRefresh),
      trailing: _HomeScopeActions(
        showRefresh: showRefresh,
        refreshTooltip: refreshTooltip,
        onRefresh: onRefresh,
        onToggleUnreadOnly: onToggleUnreadOnly,
        onMarkAllRead: onMarkAllRead,
      ),
    );
  }
}

class _HomeScopeActions extends ConsumerWidget {
  const _HomeScopeActions({
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

    return FleurCapsuleButtonGroup(
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
    );
  }
}

double _homeScopeActionsWidth(bool showRefresh) {
  final actionCount = (showRefresh ? 1 : 0) + 2;
  return actionCount * kShellControlSize + 2;
}

String _homeScopeTitle(WidgetRef ref, AppLocalizations l10n) {
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
