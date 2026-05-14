import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/core_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../widgets/fleur_capsule_button_group.dart';
import '../widgets/sidebar.dart';
import '../utils/platform.dart';
import 'app_drawer_scope.dart';
import 'app_menu.dart';
import 'layout.dart';
import 'layout_spec.dart';
import 'sidebar_layout.dart';
import 'workspace_layers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.currentUri, required this.child});

  final Uri currentUri;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _temporarySidebarOpen = false;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUri != widget.currentUri && _temporarySidebarOpen) {
      _temporarySidebarOpen = false;
    }
  }

  bool _isArticleRoute(Uri uri) => uri.pathSegments.contains('article');

  double _listWidthForArticleUri(Uri uri) {
    final seg0 = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (seg0) {
      'search' => kDesktopListWidth,
      _ => kHomeListWidth,
    };
  }

  bool _isReaderEmbedded({required LayoutSpec spec, required Uri uri}) {
    if (!_isArticleRoute(uri)) return true;
    if (isDesktop) {
      return spec.desktopEmbedsReader;
    }
    return spec.canEmbedReader(listWidth: _listWidthForArticleUri(uri));
  }

  void _goToScope(BuildContext context, ArticleScope scope) {
    _closeTemporarySidebar();
    final router = GoRouter.maybeOf(context);
    final location = scopeLocation(scope);
    if (router != null) {
      router.go(location);
      return;
    }
    unawaited(Navigator.of(context).pushNamed(location));
  }

  void _goToSearch(BuildContext context) {
    _closeTemporarySidebar();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/search');
      return;
    }
    unawaited(Navigator.of(context).pushNamed('/search'));
  }

  void _closeTemporarySidebar() {
    if (!_temporarySidebarOpen) return;
    setState(() => _temporarySidebarOpen = false);
  }

  void _toggleSidebar(WidgetRef ref, {required bool usesTemporarySidebar}) {
    if (usesTemporarySidebar) {
      setState(() => _temporarySidebarOpen = !_temporarySidebarOpen);
      return;
    }

    final notifier = ref.read(sidebarPresentationModeProvider.notifier);
    notifier.state = notifier.state == SidebarPresentationMode.expanded
        ? SidebarPresentationMode.collapsed
        : SidebarPresentationMode.expanded;
  }

  void _pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  bool _canPop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    return router?.canPop() ?? Navigator.canPop(context);
  }

  Widget _sidebarDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Sidebar(
          onSelectScope: (scope) => _goToScope(context, scope),
          router: GoRouter.maybeOf(context),
          presentationModeOverride: SidebarPresentationMode.expanded,
        ),
      ),
    );
  }

  Widget _desktopSidebar({
    required BuildContext context,
    required double width,
    SidebarPresentationMode? presentationModeOverride,
  }) {
    return SizedBox(
      width: width,
      child: Sidebar(
        onSelectScope: (scope) => _goToScope(context, scope),
        reserveShellHeader: isDesktop,
        presentationModeOverride: presentationModeOverride,
      ),
    );
  }

  Widget _withDesktopShellControlsOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required SidebarPresentationMode presentationMode,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required bool usesTemporarySidebar,
  }) {
    if (!isDesktop) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: _shellControlsLeftInset(macOSWindowChromeMetrics, fallback: 12),
          top: _shellControlsTopInset(macOSWindowChromeMetrics),
          child: _InlineShellControlsHost(
            presentationMode: presentationMode,
            canPop: _canPop(context),
            onToggleSidebar: () =>
                _toggleSidebar(ref, usesTemporarySidebar: usesTemporarySidebar),
            onPop: () => _pop(context),
            onSearch: () => _goToSearch(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSecondaryLayer({
    required BuildContext context,
    required Size size,
    required FleurSurfaceTheme surfaces,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required double sidebarWidth,
    required double listWidth,
  }) {
    return AppMenuHost(
      child: ShellLayerScope(
        totalSize: size,
        contentSize: size,
        sidebarLayoutMode: sidebarLayoutModeForWidth(size.width),
        contentLeft: 0,
        contentLeadingInset: 0,
        railOverlayVisible: false,
        sidebarWidth: sidebarWidth,
        listWidth: listWidth,
        headerLeadingInset: 14,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        child: AppDrawerScope(
          hasAppDrawer: false,
          child: WorkspaceLayerSurface(
            key: const Key('app_shell_secondary_layer'),
            color: surfaces.reader,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayeredShell({
    required BuildContext context,
    required WidgetRef ref,
    required Size size,
    required SidebarPresentationMode presentationMode,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required FleurSurfaceTheme surfaces,
    required double sidebarWidth,
    required double listWidth,
  }) {
    final sidebarLayoutMode = sidebarLayoutModeForWidth(size.width);
    final hasInlineSidebar = sidebarLayoutMode == SidebarLayoutMode.inline;
    final sidebarExpanded =
        hasInlineSidebar &&
        presentationMode == SidebarPresentationMode.expanded;
    final temporarySidebarOpen = !hasInlineSidebar && _temporarySidebarOpen;
    final contentLeft = sidebarExpanded
        ? sidebarWidth + kSidebarContentDividerWidth
        : (temporarySidebarOpen ? sidebarWidth : 0.0);
    final contentWidth = sidebarExpanded
        ? (size.width - contentLeft).clamp(0.0, double.infinity).toDouble()
        : size.width;
    final railOverlayVisible = !sidebarExpanded && !temporarySidebarOpen;
    final contentLeadingInset = railOverlayVisible
        ? kSidebarRailWidth + 16
        : 0.0;
    final controlsPresentationMode = sidebarExpanded || temporarySidebarOpen
        ? SidebarPresentationMode.expanded
        : SidebarPresentationMode.collapsed;
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      fallback: 12,
    );
    final controlsRight = controlsLeft + _kShellControlsGroupWidth;
    final overlapWithContent = controlsRight - contentLeft;
    final headerLeadingInset = overlapWithContent > 0
        ? overlapWithContent + 8
        : 14.0;

    final contentLayer = ShellLayerScope(
      totalSize: size,
      contentSize: Size(contentWidth, size.height),
      sidebarLayoutMode: sidebarLayoutMode,
      contentLeft: contentLeft,
      contentLeadingInset: contentLeadingInset,
      railOverlayVisible: railOverlayVisible,
      sidebarWidth: sidebarWidth,
      listWidth: listWidth,
      headerLeadingInset: headerLeadingInset,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      child: WorkspaceLayerSurface(
        key: const Key('app_shell_content_layer'),
        color: surfaces.list,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: widget.child,
              ),
            ),
            if (railOverlayVisible)
              Positioned(
                key: const Key('app_shell_rail_overlay'),
                left: 0,
                top: 0,
                bottom: 0,
                width: kSidebarRailWidth,
                child: Sidebar(
                  onSelectScope: (scope) => _goToScope(context, scope),
                  reserveShellHeader: true,
                  transparentBackground: true,
                  presentationModeOverride: SidebarPresentationMode.collapsed,
                ),
              ),
          ],
        ),
      ),
    );

    return AppMenuHost(
      child: DecoratedBox(
        decoration: BoxDecoration(color: surfaces.chrome),
        child: AppDrawerScope(
          hasAppDrawer: true,
          child: _withDesktopShellControlsOverlay(
            context: context,
            ref: ref,
            presentationMode: controlsPresentationMode,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            usesTemporarySidebar: !hasInlineSidebar,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: sidebarWidth,
                  child: _desktopSidebar(
                    context: context,
                    width: sidebarWidth,
                    presentationModeOverride: SidebarPresentationMode.expanded,
                  ),
                ),
                if (sidebarExpanded) ...[
                  Positioned(
                    key: const Key('app_shell_sidebar_divider'),
                    left: sidebarWidth,
                    top: 0,
                    bottom: 0,
                    width: kSidebarContentDividerWidth,
                    child: ColoredBox(color: surfaces.subtleDivider),
                  ),
                  Positioned(
                    key: const Key('app_shell_sidebar_split_handle'),
                    left: sidebarWidth - kWorkspaceSplitHandleHitWidth / 2,
                    top: 0,
                    bottom: 0,
                    width: kWorkspaceSplitHandleHitWidth,
                    child: WorkspaceSplitHandle(
                      onDragDelta: (delta) {
                        final notifier = ref.read(
                          workspaceSidebarWidthProvider.notifier,
                        );
                        notifier.state = (notifier.state + delta)
                            .clamp(
                              kMinWorkspaceSidebarWidth,
                              kMaxWorkspaceSidebarWidth,
                            )
                            .toDouble();
                      },
                    ),
                  ),
                ],
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: contentLeft,
                  top: 0,
                  bottom: 0,
                  width: contentWidth,
                  child: contentLayer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _withDesktopDrawerControlsOverlay({
    required BuildContext context,
    required Widget child,
    required VoidCallback? openDrawer,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
  }) {
    if (!isDesktop || openDrawer == null) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          top: 0,
          child: _DrawerControlsHost(
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            canPop: _canPop(context),
            onPop: () => _pop(context),
            openDrawer: openDrawer,
            onSearch: () => _goToSearch(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final presentationMode = ref.watch(sidebarPresentationModeProvider);
    final sidebarWidth = ref
        .watch(workspaceSidebarWidthProvider)
        .clamp(kMinWorkspaceSidebarWidth, kMaxWorkspaceSidebarWidth);
    final listWidth = ref
        .watch(workspaceListWidthProvider)
        .clamp(kMinWorkspaceListWidth, kMaxWorkspaceListWidth);
    final macOSWindowChromeMetrics = ref.watch(
      macOSWindowChromeMetricsProvider,
    );
    final spec = LayoutSpec.fromTotalSize(
      totalWidth: size.width,
      totalHeight: size.height,
      sidebarPresentationMode:
          sidebarLayoutModeForWidth(size.width) == SidebarLayoutMode.inline
          ? presentationMode
          : SidebarPresentationMode.collapsed,
      sidebarWidth: sidebarWidth.toDouble(),
      listWidth: listWidth.toDouble(),
    );
    final surfaces = Theme.of(context).fleurSurface;
    final hideNavForReaderPage =
        _isArticleRoute(widget.currentUri) &&
        !_isReaderEmbedded(spec: spec, uri: widget.currentUri);

    Widget wrapShell(Widget shell) {
      return AppMenuHost(
        child: DecoratedBox(
          decoration: BoxDecoration(color: surfaces.chrome),
          child: shell,
        ),
      );
    }

    if (hideNavForReaderPage) {
      if (isDesktop) {
        return _buildDesktopSecondaryLayer(
          context: context,
          size: size,
          surfaces: surfaces,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          sidebarWidth: sidebarWidth.toDouble(),
          listWidth: listWidth.toDouble(),
        );
      }
      return wrapShell(
        AppDrawerScope(hasAppDrawer: false, child: widget.child),
      );
    }

    if (isDesktop) {
      return _buildDesktopLayeredShell(
        context: context,
        ref: ref,
        size: size,
        presentationMode: presentationMode,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        surfaces: surfaces,
        sidebarWidth: sidebarWidth.toDouble(),
        listWidth: listWidth.toDouble(),
      );
    }

    return wrapShell(
      Scaffold(
        drawer: _sidebarDrawer(context),
        body: Builder(
          builder: (scaffoldContext) {
            void openDrawer() => Scaffold.of(scaffoldContext).openDrawer();

            return AppDrawerScope(
              hasAppDrawer: true,
              openDrawer: openDrawer,
              child: _withDesktopDrawerControlsOverlay(
                context: context,
                openDrawer: openDrawer,
                macOSWindowChromeMetrics: macOSWindowChromeMetrics,
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const double _kShellControlsGroupWidth = kShellControlSize * 4;

double _shellControlsLeftInset(
  MacOSWindowChromeMetrics metrics, {
  required double fallback,
}) {
  if (!isMacOS) return fallback;
  return metrics.trafficLightsVisible ? metrics.safeInset : fallback;
}

double _shellControlsTopInset(MacOSWindowChromeMetrics metrics) {
  if (!isMacOS) return kShellControlTopInset;
  return metrics.shellControlTopInset;
}

class _InlineShellControlsHost extends StatelessWidget {
  const _InlineShellControlsHost({
    required this.presentationMode,
    required this.canPop,
    required this.onToggleSidebar,
    required this.onPop,
    required this.onSearch,
  });

  final SidebarPresentationMode presentationMode;
  final bool canPop;
  final VoidCallback onToggleSidebar;
  final VoidCallback onPop;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final controls = [
      _ShellControlData(
        key: const Key('shell_sidebar_button'),
        tooltip: sidebarExpanded ? l10n.collapse : l10n.expand,
        onPressed: onToggleSidebar,
        icon: sidebarExpanded
            ? FleurIcons.sidebarCollapse
            : FleurIcons.sidebarExpand,
      ),
      _ShellControlData(
        key: const Key('shell_back_button'),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: canPop ? onPop : null,
        icon: FleurIcons.back,
      ),
      _ShellControlData(
        key: const Key('shell_forward_button'),
        tooltip: MaterialLocalizations.of(context).nextPageTooltip,
        onPressed: null,
        icon: FleurIcons.forward,
      ),
      _ShellControlData(
        key: const Key('shell_search_button'),
        tooltip: l10n.search,
        onPressed: onSearch,
        icon: FleurIcons.search,
      ),
    ];

    if (!sidebarExpanded) {
      return FleurCapsuleButtonGroup(
        key: const Key('shell_controls_capsule'),
        height: kShellControlCapsuleHeight,
        padding: EdgeInsets.zero,
        children: [
          for (final control in controls)
            FleurCapsuleIconButton(
              key: control.key,
              tooltip: control.tooltip,
              onPressed: control.onPressed,
              icon: control.icon,
              size: kShellControlSize,
              iconSize: kShellControlIconSize,
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final control in controls)
          _DrawerControlButton(
            key: control.key,
            tooltip: control.tooltip,
            onPressed: control.onPressed,
            icon: control.icon,
          ),
      ],
    );
  }
}

class _ShellControlData {
  const _ShellControlData({
    required this.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key key;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
}

class _DrawerControlsHost extends StatelessWidget {
  const _DrawerControlsHost({
    required this.macOSWindowChromeMetrics,
    required this.canPop,
    required this.onPop,
    required this.openDrawer,
    required this.onSearch,
  });

  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final bool canPop;
  final VoidCallback onPop;
  final VoidCallback openDrawer;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      key: const Key('shell_drawer_controls'),
      height: kWorkspaceHeaderHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: _shellControlsLeftInset(macOSWindowChromeMetrics, fallback: 8),
          top: _shellControlsTopInset(macOSWindowChromeMetrics),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DrawerControlButton(
              key: const Key('shell_sidebar_button'),
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: openDrawer,
              icon: FleurIcons.sidebarExpand,
            ),
            _DrawerControlButton(
              key: const Key('shell_back_button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: canPop ? onPop : null,
              icon: FleurIcons.back,
            ),
            _DrawerControlButton(
              key: const Key('shell_forward_button'),
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
              onPressed: null,
              icon: FleurIcons.forward,
            ),
            _DrawerControlButton(
              key: const Key('shell_search_button'),
              tooltip: l10n.search,
              onPressed: onSearch,
              icon: FleurIcons.search,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerControlButton extends StatelessWidget {
  const _DrawerControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: kShellControlIconSize),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(kShellControlSize),
        minimumSize: const Size.square(kShellControlSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
