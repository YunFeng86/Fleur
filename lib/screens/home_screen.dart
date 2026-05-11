import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../providers/backend_capabilities_provider.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/unread_providers.dart';
import '../theme/fleur_icons.dart';
import '../ui/actions/subscription_object_menus.dart';
import '../ui/global_nav.dart';
import '../ui/hero_tags.dart';
import '../ui/home/home_scene_commands.dart';
import '../ui/home/home_scene_panes.dart';
import '../ui/home/home_scene_shortcuts.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../utils/platform.dart';
import '../widgets/outbox_status_action.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Desktop has a top title bar provided by App chrome; avoid in-page AppBar.
    final useCompactTopBar = !isDesktop;
    final showSyncCapsule =
        LayoutSpec.fromContext(context).globalNavMode == GlobalNavMode.rail;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final showRootRefresh = SubscriptionObjectMenus.showsRootRefresh(
      capabilities,
    );
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final refreshActionLabel = SubscriptionObjectMenus.rootRefreshLabel(
      l10n,
      capabilities,
      syncSemantics,
    );
    final refreshSuccessLabel = SubscriptionObjectMenus.rootRefreshSuccessLabel(
      l10n,
      capabilities,
      syncSemantics,
    );
    final commands = HomeSceneCommands(
      context: context,
      ref: ref,
      selectedArticleId: selectedArticleId,
    );

    Future<void> refreshAll() async {
      final batch = await commands.refreshAll();
      final err = batch.firstError?.error;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null
                ? refreshSuccessLabel
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
        final columns = homeColumnsForWidth(width);

        if (isDesktop) {
          final mode = desktopModeForWidth(width);
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
          );
        }

        // 1-column: mobile-style list + drawer, dedicated reader route.
        if (columns == 1) {
          final unreadOnly = ref.watch(unreadOnlyProvider);
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.feeds),
              actions: [
                if (showRootRefresh)
                  IconButton(
                    tooltip: refreshActionLabel,
                    onPressed: refreshAll,
                    icon: const Icon(FleurIcons.refresh),
                  ),
                // On mobile we have dedicated Saved/Search tabs in the
                // global bottom navigation. Avoid duplicating those
                // shortcuts here to keep the AppBar focused on feed-only
                // actions.
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
            drawer: const HomeSidebarDrawer(),
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
            drawer: columns == 2 ? const HomeSidebarDrawer() : null,
            body: Row(
              children: [
                if (columns == 3) ...[
                  HomeSidebarRouteAwarePane(
                    width: kHomeSidebarWidth,
                    showSyncCapsule: showSyncCapsule,
                    selectedArticleId: selectedArticleId,
                  ),
                  const SizedBox(width: kPaneGap),
                ],
                HomeArticleListPane(
                  width: kHomeListWidth,
                  selectedArticleId: selectedArticleId,
                  showSyncCapsule: showSyncCapsule && columns != 3,
                ),
                const SizedBox(width: kPaneGap),
                Expanded(
                  child: HomeReaderPane(
                    selectedArticleId: selectedArticleId,
                    placeholderText: l10n.selectAnArticle,
                  ),
                ),
              ],
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
  ) {
    final showSyncCapsule =
        LayoutSpec.fromContext(context).globalNavMode == GlobalNavMode.rail;
    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    final body = switch (mode) {
      DesktopPaneMode.threePane => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sidebarVisible) ...[
            HomeSidebarRouteAwarePane(
              width: kDesktopSidebarWidth,
              showSyncCapsule: showSyncCapsule,
              selectedArticleId: selectedArticleId,
              hero: true,
            ),
            const SizedBox(width: kPaneGap),
          ],
          HomeArticleListPane(
            width: kDesktopListWidth,
            heroTag: kHeroArticleListPane,
            selectedArticleId: selectedArticleId,
            showSyncCapsule: showSyncCapsule && !sidebarVisible,
          ),
          const SizedBox(width: kPaneGap),
          Expanded(
            child: HomeReaderPane(
              selectedArticleId: selectedArticleId,
              placeholderText: l10n.selectAnArticle,
            ),
          ),
        ],
      ),
      DesktopPaneMode.splitListReader => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeArticleListPane(
            width: kDesktopListWidth,
            heroTag: kHeroArticleListPane,
            selectedArticleId: selectedArticleId,
            showSyncCapsule: showSyncCapsule,
          ),
          const SizedBox(width: kPaneGap),
          Expanded(
            child: HomeReaderPane(
              selectedArticleId: selectedArticleId,
              placeholderText: l10n.selectAnArticle,
            ),
          ),
        ],
      ),
      DesktopPaneMode.listOnly => HomeArticleListPane(
        selectedArticleId: selectedArticleId,
        showSyncCapsule: showSyncCapsule,
      ),
    };

    final content = HomeSceneShortcuts(commands: commands, child: body);

    if (!useCompactTopBar) return content;

    final drawerEnabled = sidebarVisible && desktopSidebarInDrawer(mode);

    return Scaffold(
      appBar: AppBar(
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
      drawer: drawerEnabled ? const HomeSidebarDrawer() : null,
      body: content,
    );
  }
}
