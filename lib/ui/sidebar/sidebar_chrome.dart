part of 'sidebar.dart';

enum _SidebarAccountMenuAction { account, settings }

const double _kSidebarFixedItemHeight = 40;
const double _kSidebarRailButtonSize = kShellControlSize;
const double _kSidebarRailIconSize = kShellControlIconSize;
const double _kSidebarAccountHeight = 56;
const double _kSidebarRailHorizontalInset = 10;
const double _kSidebarAccountAvatarRadius = 16;

bool _isSidebarSearchRoute(Uri? uri) {
  if (uri == null || uri.pathSegments.isEmpty) return false;
  return uri.pathSegments.first == 'search';
}

bool _isSidebarAddSubscriptionRoute(Uri? uri) {
  if (uri == null || uri.pathSegments.isEmpty) return false;
  return uri.pathSegments.first == 'add-subscription';
}

List<_SidebarFixedItemData> _fixedScopeItems({
  required BuildContext context,
  required ArticleScope currentScope,
  required int allUnreadCount,
  required bool suppressScopeSelection,
  required bool addSubscriptionSelected,
  required bool showAddSubscription,
  required VoidCallback onSelectAll,
  required VoidCallback onSelectStarred,
  required VoidCallback onSelectReadLater,
  required VoidCallback onAddSubscription,
}) {
  final l10n = AppLocalizations.of(context)!;
  return [
    _SidebarFixedItemData(
      key: const Key('sidebar_all_button'),
      selected: !suppressScopeSelection && currentScope == ArticleScope.all,
      icon: FleurIcons.feed,
      title: l10n.all,
      count: allUnreadCount,
      onTap: onSelectAll,
    ),
    _SidebarFixedItemData(
      key: const Key('sidebar_starred_button'),
      selected: !suppressScopeSelection && currentScope == ArticleScope.starred,
      icon: FleurIcons.star,
      selectedIcon: FleurIcons.starActive,
      title: l10n.starred,
      onTap: onSelectStarred,
    ),
    _SidebarFixedItemData(
      key: const Key('sidebar_read_later_button'),
      selected:
          !suppressScopeSelection && currentScope == ArticleScope.readLater,
      icon: FleurIcons.readLater,
      selectedIcon: FleurIcons.readLaterActive,
      title: l10n.readLater,
      onTap: onSelectReadLater,
    ),
    if (showAddSubscription)
      _SidebarFixedItemData(
        key: const Key('sidebar_add_subscription_button'),
        selected: addSubscriptionSelected,
        icon: FleurIcons.add,
        title: l10n.addSubscription,
        onTap: onAddSubscription,
      ),
  ];
}

class _SidebarFixedItemData {
  const _SidebarFixedItemData({
    required this.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.selectedIcon,
    this.count,
  });

  final Key key;
  final bool selected;
  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  IconData get effectiveIcon => selected ? (selectedIcon ?? icon) : icon;
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.fixedItems,
    required this.account,
    required this.sync,
    required this.showSyncStatus,
    required this.onAccountTap,
    required this.reserveShellHeader,
    required this.navigationTree,
    required this.navigationScrollController,
    required this.showRailAnchors,
  });

  final List<_SidebarFixedItemData> fixedItems;
  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onAccountTap;
  final bool reserveShellHeader;
  final Widget navigationTree;
  final ScrollController navigationScrollController;
  final bool showRailAnchors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (reserveShellHeader) const _SidebarPanelHeader(),
        _SidebarPanelFixedItems(
          items: fixedItems,
          scrollController: navigationScrollController,
          showRailAnchors: showRailAnchors,
        ),
        Expanded(child: navigationTree),
        _AccountPanelFooter(
          account: account,
          sync: sync,
          showSyncStatus: showSyncStatus,
          onTap: onAccountTap,
          showRailAnchor: false,
        ),
      ],
    );
  }
}

class _SidebarPanelHeader extends StatelessWidget {
  const _SidebarPanelHeader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('app_shell_sidebar_header'),
      height: kWorkspaceHeaderHeight,
    );
  }
}

class _SidebarPanelFixedItems extends StatelessWidget {
  const _SidebarPanelFixedItems({
    required this.items,
    required this.scrollController,
    required this.showRailAnchors,
  });

  final List<_SidebarFixedItemData> items;
  final ScrollController scrollController;
  final bool showRailAnchors;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _SidebarPanelFixedItem(
                item: item,
                showRailAnchor: showRailAnchors,
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: scrollController,
            builder: (context, _) {
              final showDivider =
                  scrollController.hasClients && scrollController.offset > 0.5;
              return AnimatedOpacity(
                opacity: showDivider ? 1 : 0,
                duration: duration,
                curve: AppMotion.standardCurve,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: surfaces.subtleDivider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarPanelFixedItem extends StatelessWidget {
  const _SidebarPanelFixedItem({
    required this.item,
    required this.showRailAnchor,
  });

  final _SidebarFixedItemData item;
  final bool showRailAnchor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final scheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(8);
    final railWidth = SidebarRailLayoutScope.widthOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        height: _kSidebarFixedItemHeight,
        child: Semantics(
          button: true,
          selected: item.selected,
          label: item.title,
          child: FleurSelectableButton(
            selected: item.selected,
            onPressed: item.onTap,
            minimumHeight: _kSidebarFixedItemHeight,
            borderRadius: borderRadius,
            selectedBackgroundColor: surfaces.cardSelected,
            selectedForegroundColor: scheme.primary,
            unselectedForegroundColor: scheme.onSurfaceVariant,
            child: ListTile(
              selected: item.selected,
              selectedTileColor: Colors.transparent,
              tileColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              minTileHeight: _kSidebarFixedItemHeight,
              minLeadingWidth: railWidth - 16,
              horizontalTitleGap: 8,
              contentPadding: const EdgeInsets.only(right: 8),
              leading: SizedBox(
                width: railWidth - 16,
                child: Center(
                  child: SizedBox.square(
                    key: showRailAnchor ? item.key : null,
                    dimension: _kSidebarRailButtonSize,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
              trailing: item.count == null
                  ? null
                  : _SidebarFixedCount(item.count!),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFixedCount extends StatelessWidget {
  const _SidebarFixedCount(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Text(
      count > 99 ? '99+' : '$count',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _AccountPanelFooter extends StatelessWidget {
  const _AccountPanelFooter({
    required this.account,
    required this.sync,
    required this.showSyncStatus,
    required this.onTap,
    required this.showRailAnchor,
  });

  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onTap;
  final bool showRailAnchor;

  String _syncText(AppLocalizations l10n) {
    String labelFor(SyncStatusLabel label) => switch (label) {
      SyncStatusLabel.syncing => l10n.syncStatusSyncing,
      SyncStatusLabel.syncingFeeds => l10n.syncStatusSyncingFeeds,
      SyncStatusLabel.syncingSubscriptions =>
        l10n.syncStatusSyncingSubscriptions,
      SyncStatusLabel.syncingUnreadArticles =>
        l10n.syncStatusSyncingUnreadArticles,
      SyncStatusLabel.uploadingChanges => l10n.syncStatusUploadingChanges,
      SyncStatusLabel.completed => l10n.syncStatusCompleted,
      SyncStatusLabel.failed => l10n.syncStatusFailed,
    };

    final label = labelFor(sync.label);
    final base = label;
    final cur = sync.current;
    final total = sync.total;
    if (cur != null && total != null && total > 0) {
      return '$base（$cur/$total）';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final scheme = theme.colorScheme;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;
    final railWidth = SidebarRailLayoutScope.widthOf(context);

    final showSync = showSyncStatus && sync.visible;
    final syncText = _syncText(l10n);
    final borderRadius = BorderRadius.circular(8);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.card,
          border: Border(top: BorderSide(color: surfaces.subtleDivider)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(
            message: account.name,
            child: Semantics(
              button: true,
              label: account.name,
              child: Material(
                color: Colors.transparent,
                borderRadius: borderRadius,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  hoverColor: states.hoverTint,
                  child: SizedBox(
                    height: _kSidebarAccountHeight - 12,
                    child: Row(
                      children: [
                        SizedBox(
                          width: railWidth - 12,
                          child: Center(
                            child: SizedBox.square(
                              key: showRailAnchor
                                  ? const Key('sidebar_account_button')
                                  : null,
                              dimension: _kSidebarRailButtonSize,
                              child: Opacity(
                                opacity: 0,
                                child: AccountAvatar(
                                  account: account,
                                  radius: _kSidebarAccountAvatarRadius,
                                  showTypeBadge: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                    height: 1.2,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: duration,
                                  switchInCurve: AppMotion.standardCurve,
                                  switchOutCurve:
                                      AppMotion.emphasizedAccelerate,
                                  transitionBuilder: (child, animation) {
                                    return SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: showSync
                                      ? Padding(
                                          key: const ValueKey('sync'),
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              if (sync.running)
                                                const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              else
                                                Icon(
                                                  sync.label ==
                                                          SyncStatusLabel.failed
                                                      ? FleurIcons.statusError
                                                      : FleurIcons.statusOk,
                                                  size: 12,
                                                  color:
                                                      sync.label ==
                                                          SyncStatusLabel.failed
                                                      ? states.errorAccent
                                                      : states.syncAccent,
                                                ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: OverflowMarquee(
                                                  text: syncText,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        letterSpacing: 0,
                                                        height: 1.15,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(key: ValueKey('empty')),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          FleurIcons.accountSwitcher,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
