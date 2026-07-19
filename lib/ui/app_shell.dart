import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/app_update_providers.dart';
import '../providers/core_providers.dart';
import '../providers/navigation_history_provider.dart';
import '../services/update/app_update_manifest.dart';
import '../theme/fleur_theme_extensions.dart';
import '../widgets/sidebar.dart';
import '../utils/platform.dart';
import 'adaptive_workspace_layout.dart';
import 'app_drawer_scope.dart';
import 'app_menu.dart';
import 'layout.dart';
import 'layout_spec.dart';
import 'shell_chrome_layout.dart';
import 'shell_control_strip.dart';
import 'shell_frame_geometry.dart';
import 'shell_title_bar.dart';
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
  bool _navigationHistoryBindScheduled = false;
  double? _sidebarResizeVirtualWidth;
  GoRouter? _pendingNavigationHistoryRouter;
  Size? _lastWindowSize;
  final FocusNode _navigationToggleFocusNode = FocusNode(
    debugLabel: 'shell-navigation-toggle',
  );
  final FocusNode _temporaryNavigationFocusNode = FocusNode(
    debugLabel: 'shell-temporary-navigation',
  );

  @override
  void dispose() {
    _navigationToggleFocusNode.dispose();
    _temporaryNavigationFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_lastWindowSize != null &&
        _lastWindowSize != size &&
        _temporarySidebarOpen) {
      _temporarySidebarOpen = false;
    }
    _lastWindowSize = size;
  }

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

  bool _isSearchRoute(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'search';

  void _scheduleNavigationHistoryBind(GoRouter? router) {
    if (router == null) return;
    _pendingNavigationHistoryRouter = router;
    if (_navigationHistoryBindScheduled) return;

    _navigationHistoryBindScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationHistoryBindScheduled = false;
      if (!mounted) return;
      final router = _pendingNavigationHistoryRouter;
      if (router == null) return;
      ref.read(navigationHistoryControllerProvider.notifier).bindRouter(router);
    });
  }

  void _closeTemporarySidebar() {
    if (!_temporarySidebarOpen) return;
    setState(() => _temporarySidebarOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_navigationToggleFocusNode.canRequestFocus) return;
      _navigationToggleFocusNode.requestFocus();
    });
  }

  void _toggleResolvedNavigation(
    WidgetRef ref, {
    required AdaptiveWorkspaceArrangement arrangement,
    required SidebarPresentationMode preferredNavigation,
  }) {
    if (_temporarySidebarOpen) {
      _closeTemporarySidebar();
      return;
    }

    if (arrangement.navigationPresentation ==
        WorkspaceNavigationPresentation.expanded) {
      ref.read(sidebarPresentationModeProvider.notifier).state =
          SidebarPresentationMode.collapsed;
      return;
    }

    if (preferredNavigation == SidebarPresentationMode.collapsed) {
      ref.read(sidebarPresentationModeProvider.notifier).state =
          SidebarPresentationMode.expanded;
    }
    setState(() => _temporarySidebarOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_temporaryNavigationFocusNode.canRequestFocus) return;
      _temporaryNavigationFocusNode.requestFocus();
    });
  }

  void _beginSidebarResize(double sidebarWidth) {
    _sidebarResizeVirtualWidth = sidebarWidth;
  }

  void _updateSidebarResize({
    required WidgetRef ref,
    required double delta,
    required double totalWidth,
  }) {
    final widthNotifier = ref.read(workspaceSidebarWidthProvider.notifier);
    final currentVirtualWidth =
        _sidebarResizeVirtualWidth ??
        clampWorkspaceSidebarWidth(widthNotifier.state, totalWidth);
    final nextVirtualWidth = currentVirtualWidth + delta;

    final shouldCollapse = nextVirtualWidth <= _kSidebarCollapseThresholdWidth;
    if (shouldCollapse) {
      _collapseSidebarFromResize(ref);
      return;
    }

    _sidebarResizeVirtualWidth = nextVirtualWidth;
    widthNotifier.state = clampWorkspaceSidebarWidth(
      nextVirtualWidth,
      totalWidth,
    );
  }

  void _collapseSidebarFromResize(WidgetRef ref) {
    _clearSidebarResizeState();
    ref.read(workspaceSidebarWidthProvider.notifier).state =
        kMinWorkspaceSidebarWidth;
    ref.read(sidebarPresentationModeProvider.notifier).state =
        SidebarPresentationMode.collapsed;
  }

  void _clearSidebarResizeState() {
    _sidebarResizeVirtualWidth = null;
  }

  Widget _desktopSidebar({
    required BuildContext context,
    required double width,
    required bool showAccountSyncStatus,
    required Uri currentUri,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required ShellChromeLayout shellChromeLayout,
    VoidCallback? onSearch,
    SidebarPresentationMode? presentationModeOverride,
  }) {
    return SizedBox(
      width: width,
      child: Sidebar(
        onSelectScope: (scope) => _goToScope(context, scope),
        reserveShellHeader:
            isDesktop && !shellChromeLayout.placesControlsInTitleBar,
        presentationModeOverride: presentationModeOverride,
        showAccountSyncStatus: showAccountSyncStatus,
        currentUri: currentUri,
        onSearch: onSearch,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        railSurfaceStyle: shellChromeLayout.railSurfaceStyle,
        showHeaderActions: !shellChromeLayout.placesControlsInTitleBar,
      ),
    );
  }

  Widget _withDesktopShellControlsOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required SidebarPresentationMode presentationMode,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required ShellChromeLayout shellChromeLayout,
    required AdaptiveWorkspaceArrangement arrangement,
    required SidebarPresentationMode preferredNavigation,
    required bool searchSelected,
    required NavigationHistoryState history,
    required AppUpdateManifest? updateManifest,
  }) {
    if (!isDesktop) return child;
    if (shellChromeLayout.placesControlsInTitleBar) return child;
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () => _toggleResolvedNavigation(
        ref,
        arrangement: arrangement,
        preferredNavigation: preferredNavigation,
      ),
      onSearch: () => _goToSearch(context),
    );
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: _shellControlsLeftInset(
            macOSWindowChromeMetrics,
            shellChromeLayout: shellChromeLayout,
            fallback: 12,
          ),
          top: _shellControlsTopInset(
            macOSWindowChromeMetrics,
            shellChromeLayout: shellChromeLayout,
          ),
          child: _InlineShellControlsHost(
            presentationMode: presentationMode,
            shellChromeLayout: shellChromeLayout,
            commands: commands,
            searchSelected: searchSelected,
            updateManifest: updateManifest,
            navigationToggleFocusNode: _navigationToggleFocusNode,
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
    required ShellChromeLayout shellChromeLayout,
    required double sidebarWidth,
    required double listWidth,
    required SidebarPresentationMode preferredNavigation,
    required AdaptiveWorkspaceArrangement arrangement,
  }) {
    final usesTitleBar = shellChromeLayout.placesControlsInTitleBar;
    final titleBarHeight = usesTitleBar ? kWorkspaceHeaderHeight : 0.0;
    final workspaceHeight = (size.height - titleBarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    final surfaceAppearance = WorkspaceLayerSurfaceAppearance.resolve(
      shellChromeLayout,
    );

    return AppMenuHost(
      child: ShellLayerScope(
        totalSize: size,
        contentSize: Size(size.width, workspaceHeight),
        sidebarLayoutMode: sidebarLayoutModeForWidth(size.width),
        contentLeft: 0,
        contentLeadingInset: 0,
        railOverlayVisible: false,
        sidebarWidth: sidebarWidth,
        listWidth: listWidth,
        headerLeadingInset: 14,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        shellChromeLayout: shellChromeLayout,
        preferredSidebarPresentationMode: preferredNavigation,
        workspaceArrangement: arrangement,
        child: AppDrawerScope(
          hasAppDrawer: false,
          child: Stack(
            children: [
              if (usesTitleBar)
                const Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: kWorkspaceHeaderHeight,
                  child: ShellWindowTitleBar(),
                ),
              Positioned(
                left: 0,
                top: titleBarHeight,
                right: 0,
                bottom: 0,
                child: WorkspaceLayerSurface(
                  key: const Key('app_shell_secondary_layer'),
                  color: surfaces.reader,
                  borderRadius: surfaceAppearance.borderRadius,
                  showShadow: surfaceAppearance.showShadow,
                  leadingEdge: surfaceAppearance.leadingEdge,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayeredShell({
    required BuildContext context,
    required WidgetRef ref,
    required Size size,
    required SidebarPresentationMode preferredNavigation,
    required AdaptiveWorkspaceArrangement arrangement,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required ShellChromeLayout shellChromeLayout,
    required FleurSurfaceTheme surfaces,
    required double sidebarWidth,
    required double listWidth,
    required NavigationHistoryState history,
  }) {
    final sidebarLayoutMode = sidebarLayoutModeForWidth(size.width);
    final sidebarExpanded =
        arrangement.navigationPresentation ==
        WorkspaceNavigationPresentation.expanded;
    final usesTemporarySidebar = !sidebarExpanded;
    final temporarySidebarOpen = usesTemporarySidebar && _temporarySidebarOpen;
    final visibleSidebarWidth = temporarySidebarOpen
        ? kTemporaryWorkspaceSidebarWidth
        : sidebarWidth;
    final usesTitleBar = shellChromeLayout.placesControlsInTitleBar;
    final collapsedRailWidth = usesTitleBar
        ? kTitleBarExpectedSidebarRailWidth
        : kSidebarRailWidth;
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: arrangement.navigationPresentation,
      temporaryNavigationOpen: temporarySidebarOpen,
      expandedNavigationWidth: sidebarWidth,
      railWidth: collapsedRailWidth,
      temporaryNavigationWidth: visibleSidebarWidth,
    );
    final controlsPresentationMode = sidebarExpanded || temporarySidebarOpen
        ? SidebarPresentationMode.expanded
        : SidebarPresentationMode.collapsed;
    final updateManifest = ref.watch(
      appUpdateControllerProvider.select(
        (state) => state.hasUpdate ? state.manifest : null,
      ),
    );
    final shellShowsUpdate =
        updateManifest != null &&
        (shellChromeLayout.placesControlsInTitleBar ||
            controlsPresentationMode != SidebarPresentationMode.expanded);
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      fallback: usesTitleBar
          ? (((controlsPresentationMode == SidebarPresentationMode.expanded
                        ? kSidebarRailWidth
                        : collapsedRailWidth) -
                    kShellControlSize) /
                2)
          : 12,
    );
    final controlsRight =
        controlsLeft +
        _shellControlsGroupWidth(
          controlsPresentationMode,
          shellChromeLayout: shellChromeLayout,
          hasUpdate: shellShowsUpdate,
        );
    final overlapWithContent = controlsRight - geometry.contentLeft;
    final headerLeadingInset = usesTitleBar
        ? 14.0
        : overlapWithContent > 0
        ? overlapWithContent + 8
        : 14.0;
    final contentLayoutSpec = LayoutSpec.fromContentSize(
      contentWidth: geometry.contentWidth,
      contentHeight: geometry.workspaceHeight,
      listWidth: listWidth,
    );
    final showAccountSyncStatus = !contentLayoutSpec.showsListSyncStatusCapsule;
    final reserveSidebarHeader = !usesTitleBar;
    final contentSurfaceAppearance = WorkspaceLayerSurfaceAppearance.resolve(
      shellChromeLayout,
      floatingLeadingEdge: WorkspaceLayerEdge.level1,
    );

    final contentLayer = ShellLayerScope(
      totalSize: size,
      contentSize: Size(geometry.contentWidth, geometry.workspaceHeight),
      sidebarLayoutMode: sidebarLayoutMode,
      contentLeft: geometry.contentLeft,
      contentLeadingInset: geometry.contentLeadingInset,
      railOverlayVisible: geometry.railOverlayVisible,
      sidebarWidth: sidebarExpanded || temporarySidebarOpen
          ? visibleSidebarWidth
          : collapsedRailWidth,
      listWidth: listWidth,
      headerLeadingInset: headerLeadingInset,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      preferredSidebarPresentationMode: preferredNavigation,
      workspaceArrangement: arrangement,
      child: WorkspaceLayerSurface(
        key: const Key('app_shell_content_layer'),
        color: surfaces.list,
        borderRadius: contentSurfaceAppearance.borderRadius,
        showShadow: contentSurfaceAppearance.showShadow,
        leadingEdge: contentSurfaceAppearance.leadingEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: widget.child,
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
          openDrawer: !isDesktop
              ? () => _toggleResolvedNavigation(
                  ref,
                  arrangement: arrangement,
                  preferredNavigation: preferredNavigation,
                )
              : null,
          child: _withDesktopShellControlsOverlay(
            context: context,
            ref: ref,
            presentationMode: controlsPresentationMode,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            shellChromeLayout: shellChromeLayout,
            arrangement: arrangement,
            preferredNavigation: preferredNavigation,
            searchSelected: _isSearchRoute(widget.currentUri),
            history: history,
            updateManifest: shellShowsUpdate ? updateManifest : null,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (usesTitleBar)
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    height: kWorkspaceHeaderHeight,
                    child: ShellWindowTitleBar(
                      commands: ShellNavigationCommands(
                        context: context,
                        router: GoRouter.maybeOf(context),
                        history: history,
                        historyController: ref.read(
                          navigationHistoryControllerProvider.notifier,
                        ),
                        onToggleSidebar: () => _toggleResolvedNavigation(
                          ref,
                          arrangement: arrangement,
                          preferredNavigation: preferredNavigation,
                        ),
                        onSearch: () => _goToSearch(context),
                      ).toTitleBarCommands(),
                      presentationMode: controlsPresentationMode,
                      searchSelected: _isSearchRoute(widget.currentUri),
                      updateManifest: shellShowsUpdate ? updateManifest : null,
                      leadingLeft: controlsLeft,
                      dividerLeadingInset: geometry.dividerLeadingInset,
                      navigationToggleFocusNode: _navigationToggleFocusNode,
                    ),
                  ),
                if (sidebarExpanded ||
                    temporarySidebarOpen ||
                    geometry.structuralRailVisible)
                  Positioned(
                    left: 0,
                    top: geometry.titleBarHeight,
                    bottom: 0,
                    width: sidebarExpanded || temporarySidebarOpen
                        ? visibleSidebarWidth
                        : collapsedRailWidth,
                    child: sidebarExpanded || temporarySidebarOpen
                        ? Focus(
                            focusNode: temporarySidebarOpen
                                ? _temporaryNavigationFocusNode
                                : null,
                            autofocus: temporarySidebarOpen,
                            child: _desktopSidebar(
                              context: context,
                              width: visibleSidebarWidth,
                              showAccountSyncStatus: showAccountSyncStatus,
                              currentUri: widget.currentUri,
                              macOSWindowChromeMetrics:
                                  macOSWindowChromeMetrics,
                              shellChromeLayout: shellChromeLayout,
                              onSearch:
                                  !shellChromeLayout.placesControlsInTitleBar &&
                                      (sidebarExpanded || temporarySidebarOpen)
                                  ? () => _goToSearch(context)
                                  : null,
                              presentationModeOverride:
                                  SidebarPresentationMode.expanded,
                            ),
                          )
                        : KeyedSubtree(
                            key: const Key('app_shell_connected_rail'),
                            child: Sidebar(
                              onSelectScope: (scope) =>
                                  _goToScope(context, scope),
                              reserveShellHeader: reserveSidebarHeader,
                              transparentBackground: true,
                              presentationModeOverride:
                                  SidebarPresentationMode.collapsed,
                              showAccountSyncStatus: showAccountSyncStatus,
                              currentUri: widget.currentUri,
                              railSurfaceStyle:
                                  shellChromeLayout.railSurfaceStyle,
                              showHeaderActions:
                                  !shellChromeLayout.placesControlsInTitleBar,
                            ),
                          ),
                  ),
                if (sidebarExpanded) ...[
                  Positioned(
                    key: const Key('app_shell_sidebar_split_handle'),
                    left: sidebarWidth - kWorkspaceSplitHandleHitWidth / 2,
                    top: geometry.titleBarHeight,
                    bottom: 0,
                    width: kWorkspaceSplitHandleHitWidth,
                    child: WorkspaceSplitHandle(
                      onDragStart: (_) => _beginSidebarResize(sidebarWidth),
                      onDragDelta: (delta) {
                        _updateSidebarResize(
                          ref: ref,
                          delta: delta,
                          totalWidth: size.width,
                        );
                      },
                      onDragEnd: (_) => _clearSidebarResizeState(),
                      onDragCancel: _clearSidebarResizeState,
                      showDivider: false,
                    ),
                  ),
                ],
                AnimatedPositioned(
                  duration: _kContentLayerAnimationDuration,
                  curve: Curves.easeOutCubic,
                  left: geometry.translatedContentLeft,
                  top: geometry.titleBarHeight,
                  bottom: 0,
                  width: geometry.contentWidth,
                  child: contentLayer,
                ),
                if (temporarySidebarOpen)
                  Positioned(
                    key: const Key('app_shell_navigation_scrim'),
                    left: visibleSidebarWidth,
                    top: geometry.titleBarHeight,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeTemporarySidebar,
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  top: geometry.titleBarHeight,
                  bottom: 0,
                  width: collapsedRailWidth,
                  child: _RailOverlayHost(
                    visible: geometry.railOverlayVisible,
                    delay: _kContentLayerAnimationDuration,
                    child: Sidebar(
                      onSelectScope: (scope) => _goToScope(context, scope),
                      reserveShellHeader: reserveSidebarHeader,
                      transparentBackground: true,
                      presentationModeOverride:
                          SidebarPresentationMode.collapsed,
                      showAccountSyncStatus: showAccountSyncStatus,
                      currentUri: widget.currentUri,
                      railSurfaceStyle: shellChromeLayout.railSurfaceStyle,
                      showHeaderActions:
                          !shellChromeLayout.placesControlsInTitleBar,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    _scheduleNavigationHistoryBind(router);
    final history = ref.watch(navigationHistoryControllerProvider);
    final shortcutCommands = ShellNavigationCommands(
      context: context,
      router: router,
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () {},
      onSearch: () => _goToSearch(context),
    );
    final size = MediaQuery.sizeOf(context);
    final preferredNavigation = ref.watch(sidebarPresentationModeProvider);
    final sidebarWidth = clampWorkspaceSidebarWidth(
      ref.watch(workspaceSidebarWidthProvider),
      size.width,
    );
    final shellChromeLayout = ShellChromeLayout.resolve();
    final preferredArticleListWidth = _isArticleRoute(widget.currentUri)
        ? _listWidthForArticleUri(widget.currentUri)
        : null;
    final arrangementListWidth =
        preferredArticleListWidth ?? kCompactWorkspacePrimaryWidth;
    final arrangement = AdaptiveWorkspaceArrangement.resolve(
      totalWidth: size.width,
      preferredNavigation: preferredNavigation,
      navigationMetrics: shellChromeLayout.workspaceNavigationMetrics,
      requirements: WorkspaceLayoutRequirements.feed(
        listWidth: arrangementListWidth,
      ),
      hasReader: preferredArticleListWidth != null,
    );
    final railWidth = shellChromeLayout.placesControlsInTitleBar
        ? kTitleBarExpectedSidebarRailWidth
        : kSidebarRailWidth;
    final permanentNavigationWidth =
        switch (arrangement.navigationPresentation) {
          WorkspaceNavigationPresentation.expanded =>
            sidebarWidth + kSidebarContentDividerWidth,
          WorkspaceNavigationPresentation.rail
              when shellChromeLayout.profile !=
                  ShellChromeProfile.integratedCorner =>
            railWidth,
          _ => 0.0,
        };
    final contentWidthForList = (size.width - permanentNavigationWidth)
        .clamp(0.0, double.infinity)
        .toDouble();
    final listWidth = clampWorkspaceListWidth(
      ref.watch(workspaceListWidthProvider),
      contentWidthForList,
    );
    final macOSWindowChromeMetrics = ref.watch(
      macOSWindowChromeMetricsProvider,
    );
    final surfaces = Theme.of(context).fleurSurface;
    final hideNavForReaderPage = arrangement.showsSecondaryReader;

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
        return _ShellHistoryShortcuts(
          commands: shortcutCommands,
          child: _buildDesktopSecondaryLayer(
            context: context,
            size: size,
            surfaces: surfaces,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            shellChromeLayout: shellChromeLayout,
            sidebarWidth: sidebarWidth,
            listWidth: listWidth,
            preferredNavigation: preferredNavigation,
            arrangement: arrangement,
          ),
        );
      }
      return _ShellHistoryShortcuts(
        commands: shortcutCommands,
        child: wrapShell(
          AppDrawerScope(hasAppDrawer: false, child: widget.child),
        ),
      );
    }

    return _ShellHistoryShortcuts(
      commands: shortcutCommands,
      onDismissNavigation: _temporarySidebarOpen
          ? _closeTemporarySidebar
          : null,
      child: _buildDesktopLayeredShell(
        context: context,
        ref: ref,
        size: size,
        preferredNavigation: preferredNavigation,
        arrangement: arrangement,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        shellChromeLayout: shellChromeLayout,
        surfaces: surfaces,
        sidebarWidth: sidebarWidth,
        listWidth: listWidth,
        history: history,
      ),
    );
  }
}

const _kContentLayerAnimationDuration = Duration(milliseconds: 180);
const double _kSidebarCollapseThresholdWidth = kMinWorkspaceSidebarWidth / 2;

double _shellControlsGroupWidth(
  SidebarPresentationMode mode, {
  required ShellChromeLayout shellChromeLayout,
  required bool hasUpdate,
}) {
  final baseControlCount = shellChromeLayout.placesControlsInTitleBar
      ? 4
      : (mode == SidebarPresentationMode.expanded ? 3 : 4);
  return kShellControlSize * (baseControlCount + (hasUpdate ? 1 : 0));
}

double _shellControlsLeftInset(
  MacOSWindowChromeMetrics metrics, {
  required ShellChromeLayout shellChromeLayout,
  required double fallback,
}) {
  if (shellChromeLayout.profile != ShellChromeProfile.integratedCorner) {
    return fallback;
  }
  return metrics.trafficLightsVisible ? metrics.safeInset : fallback;
}

double _shellControlsTopInset(
  MacOSWindowChromeMetrics metrics, {
  required ShellChromeLayout shellChromeLayout,
}) {
  if (shellChromeLayout.profile != ShellChromeProfile.integratedCorner) {
    return kShellControlTopInset;
  }
  return metrics.shellControlTopInset;
}

class _RailOverlayHost extends StatefulWidget {
  const _RailOverlayHost({
    required this.visible,
    required this.delay,
    required this.child,
  });

  final bool visible;
  final Duration delay;
  final Widget child;

  @override
  State<_RailOverlayHost> createState() => _RailOverlayHostState();
}

class _RailOverlayHostState extends State<_RailOverlayHost> {
  Timer? _revealTimer;
  bool _paint = false;

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant _RailOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.delay != widget.delay) {
      _syncVisibility();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _syncVisibility() {
    _revealTimer?.cancel();
    if (!widget.visible) {
      if (_paint) setState(() => _paint = false);
      return;
    }

    if (_paint) return;
    _revealTimer = Timer(widget.delay, () {
      if (!mounted || !widget.visible) return;
      setState(() => _paint = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_paint || !widget.visible) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: !widget.visible,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: KeyedSubtree(
          key: const Key('app_shell_rail_overlay'),
          child: widget.child,
        ),
      ),
    );
  }
}

class ShellNavigationCommands {
  const ShellNavigationCommands({
    required this.context,
    required this.router,
    required this.history,
    required this.historyController,
    required this.onToggleSidebar,
    required this.onSearch,
  });

  final BuildContext context;
  final GoRouter? router;
  final NavigationHistoryState history;
  final NavigationHistoryController historyController;
  final VoidCallback onToggleSidebar;
  final VoidCallback onSearch;

  bool get canGoBack => history.canGoBack || _canPopFallback;
  bool get canGoForward => history.canGoForward;

  bool get _canPopFallback => router?.canPop() ?? Navigator.canPop(context);

  void goBack() {
    if (history.canGoBack) {
      historyController.goBack();
      return;
    }

    final router = this.router;
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  void goForward() {
    if (!history.canGoForward) return;
    historyController.goForward();
  }

  void goToSearch() => onSearch();
  void toggleSidebar() => onToggleSidebar();

  ShellWindowTitleBarCommands toTitleBarCommands() {
    return ShellWindowTitleBarCommands(
      onToggleSidebar: toggleSidebar,
      onBack: goBack,
      onForward: goForward,
      onSearch: goToSearch,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
    );
  }
}

class _ShellHistoryBackIntent extends Intent {
  const _ShellHistoryBackIntent();
}

class _ShellHistoryForwardIntent extends Intent {
  const _ShellHistoryForwardIntent();
}

class _DismissShellNavigationIntent extends Intent {
  const _DismissShellNavigationIntent();
}

class _ShellHistoryShortcuts extends StatelessWidget {
  const _ShellHistoryShortcuts({
    required this.commands,
    required this.child,
    this.onDismissNavigation,
  });

  final ShellNavigationCommands commands;
  final Widget child;
  final VoidCallback? onDismissNavigation;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
          _ShellHistoryBackIntent(),
      SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
          _ShellHistoryForwardIntent(),
      if (isMacOS) ...{
        SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            _ShellHistoryBackIntent(),
        SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            _ShellHistoryForwardIntent(),
      },
      if (onDismissNavigation != null)
        const SingleActivator(LogicalKeyboardKey.escape):
            const _DismissShellNavigationIntent(),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _ShellHistoryBackIntent: CallbackAction<_ShellHistoryBackIntent>(
            onInvoke: (intent) {
              commands.goBack();
              return null;
            },
          ),
          _ShellHistoryForwardIntent:
              CallbackAction<_ShellHistoryForwardIntent>(
                onInvoke: (intent) {
                  commands.goForward();
                  return null;
                },
              ),
          _DismissShellNavigationIntent:
              CallbackAction<_DismissShellNavigationIntent>(
                onInvoke: (intent) {
                  onDismissNavigation?.call();
                  return null;
                },
              ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _InlineShellControlsHost extends StatelessWidget {
  const _InlineShellControlsHost({
    required this.presentationMode,
    required this.shellChromeLayout,
    required this.commands,
    required this.searchSelected,
    required this.updateManifest,
    required this.navigationToggleFocusNode,
  });

  final SidebarPresentationMode presentationMode;
  final ShellChromeLayout shellChromeLayout;
  final ShellNavigationCommands commands;
  final bool searchSelected;
  final AppUpdateManifest? updateManifest;
  final FocusNode navigationToggleFocusNode;

  @override
  Widget build(BuildContext context) {
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final placesSearchInShell =
        shellChromeLayout.placesControlsInTitleBar || !sidebarExpanded;
    final updateManifest = placesSearchInShell ? this.updateManifest : null;
    return ShellControlStrip(
      commands: commands.toTitleBarCommands(),
      presentationMode: presentationMode,
      surface: !sidebarExpanded && shellChromeLayout.usesFloatingLeadingControls
          ? ShellControlStripSurface.capsule
          : ShellControlStripSurface.flat,
      searchSelected: searchSelected,
      showSearch: placesSearchInShell,
      updateManifest: updateManifest,
      updateBeforeSearch: !shellChromeLayout.placesControlsInTitleBar,
      navigationToggleFocusNode: navigationToggleFocusNode,
    );
  }
}
