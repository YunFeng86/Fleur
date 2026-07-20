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

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.mode,
    required this.items,
    required this.account,
    required this.reserveShellHeader,
    required this.onAccountTap,
    required this.accountAnchorKey,
    required this.railSurfaceStyle,
  });

  final SidebarPresentationMode mode;
  final List<_SidebarFixedItemData> items;
  final Account account;
  final bool reserveShellHeader;
  final VoidCallback onAccountTap;
  final Key accountAnchorKey;
  final SidebarRailSurfaceStyle railSurfaceStyle;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final collapsed = mode == SidebarPresentationMode.collapsed;
    final showsCapsuleSurface =
        collapsed && railSurfaceStyle == SidebarRailSurfaceStyle.capsule;
    final showsPlainDivider =
        collapsed && railSurfaceStyle == SidebarRailSurfaceStyle.plain;
    final railButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final item in items) _SidebarRailScopeButton(item: item)],
    );
    final railButtonGroup = showsCapsuleSurface
        ? DecoratedBox(
            key: const Key('sidebar_collapsed_rail_surface'),
            decoration: BoxDecoration(
              color: surfaces.floating,
              border: Border.all(color: surfaces.subtleDivider),
              borderRadius: BorderRadius.circular(999),
            ),
            child: railButtons,
          )
        : railButtons;

    final rail = Column(
      children: [
        if (reserveShellHeader) const SizedBox(height: kWorkspaceHeaderHeight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kSidebarRailHorizontalInset,
            ),
            child: Column(
              children: [
                railButtonGroup,
                const Expanded(child: SizedBox.shrink()),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: _kSidebarAccountHeight,
                    child: Center(
                      child: SizedBox.square(
                        key: accountAnchorKey,
                        dimension: _kSidebarRailButtonSize,
                        child: _SidebarRailAccountButton(
                          key: const Key('sidebar_account_button'),
                          account: account,
                          onTap: onAccountTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!showsPlainDivider) return rail;

    return DecoratedBox(
      key: const Key('sidebar_collapsed_rail_divider'),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: surfaces.subtleDivider)),
      ),
      child: rail,
    );
  }
}

class _SidebarRailScopeButton extends StatelessWidget {
  const _SidebarRailScopeButton({required this.item});

  final _SidebarFixedItemData item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSidebarFixedItemHeight,
      child: Center(
        child: Semantics(
          button: true,
          selected: item.selected,
          label: item.title,
          child: _SidebarRailIconButton(
            key: item.key,
            tooltip: item.title,
            icon: item.effectiveIcon,
            selected: item.selected,
            onPressed: item.onTap,
          ),
        ),
      ),
    );
  }
}

class _SidebarRailAccountButton extends StatelessWidget {
  const _SidebarRailAccountButton({
    super.key,
    required this.account,
    required this.onTap,
  });

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final states = Theme.of(context).fleurState;
    return Tooltip(
      message: account.name,
      child: Semantics(
        button: true,
        label: account.name,
        child: InkResponse(
          onTap: onTap,
          hoverColor: states.hoverTint,
          radius: 20,
          child: SizedBox.square(
            dimension: _kSidebarRailButtonSize,
            child: Center(
              child: AccountAvatar(
                account: account,
                radius: _kSidebarAccountAvatarRadius,
                showTypeBadge: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarRailIconButton extends StatelessWidget {
  const _SidebarRailIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: FleurAnimatedIcon(icon: icon, size: _kSidebarRailIconSize),
      iconSize: _kSidebarRailIconSize,
      style: FleurCapsuleIconButton.styleFor(
        context,
        selected: selected,
        size: _kSidebarRailButtonSize,
      ),
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.fixedItems,
    required this.account,
    required this.sync,
    required this.showSyncStatus,
    required this.onAccountTap,
    required this.accountAnchorKey,
    required this.reserveShellHeader,
    required this.searchSelected,
    required this.onSearch,
    required this.macOSWindowChromeMetrics,
    required this.showHeaderActions,
    required this.navigationTree,
    required this.navigationScrollController,
  });

  final List<_SidebarFixedItemData> fixedItems;
  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onAccountTap;
  final Key accountAnchorKey;
  final bool reserveShellHeader;
  final bool searchSelected;
  final VoidCallback? onSearch;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final bool showHeaderActions;
  final Widget navigationTree;
  final ScrollController navigationScrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (reserveShellHeader)
          _SidebarPanelHeader(
            searchSelected: searchSelected,
            onSearch: onSearch,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            showActions: showHeaderActions,
          ),
        _SidebarPanelFixedItems(
          items: fixedItems,
          scrollController: navigationScrollController,
        ),
        Expanded(child: navigationTree),
        _AccountPanelFooter(
          account: account,
          sync: sync,
          showSyncStatus: showSyncStatus,
          onTap: onAccountTap,
          accountAnchorKey: accountAnchorKey,
        ),
      ],
    );
  }
}

class _SidebarPanelHeader extends ConsumerWidget {
  const _SidebarPanelHeader({
    required this.searchSelected,
    required this.onSearch,
    required this.macOSWindowChromeMetrics,
    required this.showActions,
  });

  final bool searchSelected;
  final VoidCallback? onSearch;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showActions) {
      return const SizedBox(
        key: Key('app_shell_sidebar_header'),
        height: kWorkspaceHeaderHeight,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final onPressed = onSearch;
    final updateManifest = ref.watch(
      appUpdateControllerProvider.select(
        (state) => state.hasUpdate ? state.manifest : null,
      ),
    );
    final controlTop = isMacOS
        ? macOSWindowChromeMetrics.shellControlTopInset
        : kShellControlTopInset;

    return SizedBox(
      key: const Key('app_shell_sidebar_header'),
      height: kWorkspaceHeaderHeight,
      child: onPressed == null && updateManifest == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                const rightInset = 8.0;
                const controlGap = 6.0;
                final hasSearch = onPressed != null;
                final updateRight =
                    rightInset +
                    (hasSearch ? kShellControlSize + controlGap : 0);
                final reservedLeadingWidth = _sidebarHeaderReservedLeadingWidth(
                  macOSWindowChromeMetrics,
                );
                final updateSpace =
                    constraints.maxWidth - updateRight - reservedLeadingWidth;
                final updateTextWidth = _measureUpdateButtonWidth(context);
                final showUpdateLabel =
                    !searchSelected && updateSpace >= updateTextWidth;
                final updateWidth = showUpdateLabel
                    ? updateTextWidth
                    : kShellControlSize;

                return Stack(
                  children: [
                    if (updateManifest != null)
                      Positioned(
                        right: updateRight,
                        top: controlTop,
                        width: updateWidth,
                        height: kShellControlSize,
                        child: _SidebarUpdateButton(
                          manifest: updateManifest,
                          showLabel: showUpdateLabel,
                          labelWidth: updateTextWidth,
                        ),
                      ),
                    if (hasSearch)
                      Positioned(
                        right: rightInset,
                        top: controlTop,
                        width: kShellControlSize,
                        height: kShellControlSize,
                        child: Semantics(
                          button: true,
                          selected: searchSelected,
                          label: l10n.search,
                          child: IconButton(
                            key: const Key('shell_search_button'),
                            tooltip: l10n.search,
                            onPressed: onPressed,
                            icon: Icon(
                              searchSelected
                                  ? FleurIcons.searchSelected
                                  : FleurIcons.search,
                            ),
                            iconSize: kShellControlIconSize,
                            style: FleurCapsuleIconButton.styleFor(
                              context,
                              selected: searchSelected,
                              size: kShellControlSize,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

double _measureUpdateButtonWidth(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final style = (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w600,
  );
  final painter = TextPainter(
    text: TextSpan(text: l10n.updateAvailable, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return math.max(64.0, painter.width.ceilToDouble() + 28);
}

double _sidebarHeaderReservedLeadingWidth(
  MacOSWindowChromeMetrics macOSWindowChromeMetrics,
) {
  if (!isMacOS) return 8;
  final controlLeft = macOSWindowChromeMetrics.trafficLightsVisible
      ? macOSWindowChromeMetrics.safeInset
      : 12.0;
  const shellControlCount = 3;
  return controlLeft + shellControlCount * kShellControlSize + 6;
}

class _SidebarUpdateButton extends StatelessWidget {
  const _SidebarUpdateButton({
    required this.manifest,
    required this.showLabel,
    required this.labelWidth,
  });

  final AppUpdateManifest manifest;
  final bool showLabel;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!showLabel) {
      return Semantics(
        button: true,
        label: l10n.updateAvailable,
        child: IconButton(
          key: const Key('sidebar_update_button'),
          tooltip: l10n.updateAvailable,
          onPressed: () {
            unawaited(showAppUpdateDialog(context, manifest: manifest));
          },
          icon: const Icon(FleurIcons.download),
          iconSize: kShellControlIconSize,
          style: FleurCapsuleIconButton.styleFor(
            context,
            selected: true,
            size: kShellControlSize,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    return TextButton(
      key: const Key('sidebar_update_button'),
      onPressed: () {
        unawaited(showAppUpdateDialog(context, manifest: manifest));
      },
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size(labelWidth, kShellControlSize)),
        minimumSize: WidgetStatePropertyAll(
          Size(labelWidth, kShellControlSize),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(labelWidth, kShellControlSize),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        backgroundColor: WidgetStatePropertyAll(states.selectionTint),
        foregroundColor: WidgetStatePropertyAll(scheme.primary),
        overlayColor: WidgetStateProperty.resolveWith((stateSet) {
          if (stateSet.contains(WidgetState.pressed)) {
            return states.pressedTint;
          }
          if (stateSet.contains(WidgetState.hovered) ||
              stateSet.contains(WidgetState.focused)) {
            return states.hoverTint;
          }
          return null;
        }),
      ),
      child: Text(
        l10n.updateAvailable,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SidebarPanelFixedItems extends StatelessWidget {
  const _SidebarPanelFixedItems({
    required this.items,
    required this.scrollController,
  });

  final List<_SidebarFixedItemData> items;
  final ScrollController scrollController;

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
            for (final item in items) _SidebarPanelFixedItem(item: item),
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
  const _SidebarPanelFixedItem({required this.item});

  final _SidebarFixedItemData item;

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
                    key: item.key,
                    dimension: _kSidebarRailButtonSize,
                    child: Center(
                      child: Icon(item.icon, size: _kSidebarRailIconSize),
                    ),
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
                  fontWeight: AppTypography.platformWeight(FontWeight.w500),
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
        fontWeight: AppTypography.platformWeight(FontWeight.w600),
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
    required this.accountAnchorKey,
  });

  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onTap;
  final Key accountAnchorKey;

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
                key: accountAnchorKey,
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
                            child: AccountAvatar(
                              key: const Key('sidebar_account_button'),
                              account: account,
                              radius: _kSidebarAccountAvatarRadius,
                              showTypeBadge: true,
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
                                    fontWeight: AppTypography.platformWeight(
                                      FontWeight.w500,
                                    ),
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
                                                            AppTypography.platformWeight(
                                                              FontWeight.w500,
                                                            ),
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
