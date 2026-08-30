part of 'sidebar.dart';

class _PersistentSidebarChrome extends StatefulWidget {
  const _PersistentSidebarChrome({
    required this.collapsed,
    required this.expandedWidth,
    required this.railWidth,
    required this.rail,
    required this.detail,
  });

  final bool collapsed;
  final double expandedWidth;
  final double railWidth;
  final Widget rail;
  final Widget detail;

  @override
  State<_PersistentSidebarChrome> createState() =>
      _PersistentSidebarChromeState();
}

class _PersistentSidebarChromeState extends State<_PersistentSidebarChrome> {
  Timer? _hideDetailTimer;
  late bool _detailOffstage;

  @override
  void initState() {
    super.initState();
    _detailOffstage = widget.collapsed;
  }

  @override
  void didUpdateWidget(covariant _PersistentSidebarChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed == widget.collapsed) return;
    _hideDetailTimer?.cancel();
    if (!widget.collapsed) {
      setState(() => _detailOffstage = false);
      return;
    }

    final duration = AppMotion.effectiveDuration(
      context,
      AppMotion.navigationTransitionDuration,
    );
    if (duration == Duration.zero) {
      setState(() => _detailOffstage = true);
      return;
    }
    _hideDetailTimer = Timer(duration, () {
      if (!mounted || !widget.collapsed) return;
      setState(() => _detailOffstage = true);
    });
  }

  @override
  void dispose() {
    _hideDetailTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.effectiveDuration(
      context,
      AppMotion.navigationTransitionDuration,
    );
    final fullWidth = math.max(widget.expandedWidth, widget.railWidth);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: widget.collapsed,
              child: ExcludeSemantics(
                excluding: widget.collapsed,
                child: Offstage(
                  offstage: _detailOffstage,
                  child: AnimatedOpacity(
                    key: const Key('sidebar_detail_panel'),
                    opacity: widget.collapsed ? 0 : 1,
                    duration: duration,
                    curve: AppMotion.standardCurve,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: fullWidth,
                      maxWidth: fullWidth,
                      child: SizedBox(width: fullWidth, child: widget.detail),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.railWidth,
            child: widget.rail,
          ),
        ],
      ),
    );
  }
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
    required this.showAnchorKeys,
    required this.showRailDivider,
  });

  final SidebarPresentationMode mode;
  final List<_SidebarFixedItemData> items;
  final Account account;
  final bool reserveShellHeader;
  final VoidCallback onAccountTap;
  final Key accountAnchorKey;
  final SidebarRailSurfaceStyle railSurfaceStyle;
  final bool showAnchorKeys;
  final bool showRailDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final collapsed = mode == SidebarPresentationMode.collapsed;
    final showsCapsuleSurface =
        collapsed && railSurfaceStyle == SidebarRailSurfaceStyle.capsule;
    final showsPlainDivider =
        showRailDivider &&
        collapsed &&
        railSurfaceStyle == SidebarRailSurfaceStyle.plain;
    final railButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          _SidebarRailScopeButton(item: item, showAnchorKey: showAnchorKeys),
      ],
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

    Widget semanticRail = ExcludeSemantics(excluding: !collapsed, child: rail);
    if (showsCapsuleSurface) {
      semanticRail = KeyedSubtree(
        key: const Key('app_shell_rail_overlay'),
        child: semanticRail,
      );
    }
    if (!collapsed || railSurfaceStyle != SidebarRailSurfaceStyle.plain) {
      return semanticRail;
    }

    return KeyedSubtree(
      key: const Key('app_shell_connected_rail'),
      child: showsPlainDivider
          ? DecoratedBox(
              key: const Key('sidebar_collapsed_rail_divider'),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: surfaces.subtleDivider),
                ),
              ),
              child: semanticRail,
            )
          : semanticRail,
    );
  }
}

class _SidebarRailScopeButton extends StatelessWidget {
  const _SidebarRailScopeButton({
    required this.item,
    required this.showAnchorKey,
  });

  final _SidebarFixedItemData item;
  final bool showAnchorKey;

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
            key: showAnchorKey ? item.key : null,
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
