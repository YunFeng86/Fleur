import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/app_update_providers.dart';
import '../providers/core_providers.dart';
import '../providers/navigation_history_provider.dart';
import '../theme/fleur_theme_extensions.dart';
import 'sidebar/sidebar.dart';
import '../utils/platform.dart';
import 'adaptive_workspace_layout.dart';
import 'app_drawer_scope.dart';
import 'app_menu.dart';
import 'layout.dart';
import 'layout_spec.dart';
import 'motion.dart';
import 'shell_chrome_layout.dart';
import 'shell_control_strip.dart';
import 'shell_frame_geometry.dart';
import 'shell_secondary_scene_frame.dart';
import 'shell_scene_scope.dart';
import 'shell_temporary_navigation.dart';
import 'shell_window_frame.dart';
import 'sidebar_layout.dart';
import 'workspace_layers.dart';

part 'app_shell_support.dart';

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
  final GlobalKey _globalToolAreaKey = GlobalKey(
    debugLabel: 'shell-global-tool-area',
  );
  final FocusScopeNode _temporaryNavigationFocusNode = FocusScopeNode(
    debugLabel: 'shell-temporary-navigation',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
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
    final windowSizeChanged =
        _lastWindowSize != null && _lastWindowSize != size;
    if (windowSizeChanged) {
      _closeTemporarySidebarFromLifecycle();
      _closeSettingsTemporaryNavigationFromLifecycle();
    }
    _lastWindowSize = size;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUri != widget.currentUri && _temporarySidebarOpen) {
      _closeTemporarySidebarFromLifecycle();
    }
    if (oldWidget.currentUri != widget.currentUri &&
        ref.read(settingsTemporaryNavigationOpenProvider)) {
      _closeSettingsTemporaryNavigationFromLifecycle();
    }
  }

  bool _isArticleRoute(Uri uri) => uri.pathSegments.contains('article');

  bool _isSettingsRoute(Uri uri) =>
      uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'settings';

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
      ref
          .read(navigationHistoryControllerProvider.notifier)
          .visit(location, router: router);
      return;
    }
    unawaited(Navigator.of(context).pushNamed(location));
  }

  void _goToSearch(BuildContext context) {
    _closeTemporarySidebar();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      ref
          .read(navigationHistoryControllerProvider.notifier)
          .visit('/search', router: router);
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
    _scheduleNavigationToggleFocus();
  }

  void _closeTemporarySidebarFromLifecycle() {
    if (!_temporarySidebarOpen) return;
    _temporarySidebarOpen = false;
    _scheduleNavigationToggleFocus();
  }

  void _scheduleNavigationToggleFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_navigationToggleFocusNode.canRequestFocus) return;
      _navigationToggleFocusNode.requestFocus();
    });
  }

  void _openTemporarySidebar() {
    setState(() => _temporarySidebarOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_temporaryNavigationFocusNode.canRequestFocus) return;
      _temporaryNavigationFocusNode.requestFocus();
    });
  }

  void _setSettingsTemporaryNavigation(WidgetRef ref, bool open) {
    if (ref.read(settingsTemporaryNavigationOpenProvider) == open) return;
    ref.read(settingsTemporaryNavigationOpenProvider.notifier).state = open;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = open
          ? _temporaryNavigationFocusNode
          : _navigationToggleFocusNode;
      if (target.canRequestFocus) target.requestFocus();
    });
  }

  void _closeSettingsTemporaryNavigationFromLifecycle() {
    if (!ref.read(settingsTemporaryNavigationOpenProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setSettingsTemporaryNavigation(ref, false);
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
    Key? key,
    required BuildContext context,
    required double width,
    double? expandedWidth,
    required bool showAccountSyncStatus,
    required Uri currentUri,
    required ShellChromeLayout shellChromeLayout,
    SidebarPresentationMode? presentationModeOverride,
    bool transparentBackground = false,
  }) {
    final connectedFrame = shellChromeLayout.usesContinuousNavigationSurface;
    return SizedBox(
      key: key,
      width: width,
      child: Sidebar(
        onSelectScope: (scope) => _goToScope(context, scope),
        reserveShellHeader:
            shellChromeLayout.profile == ShellChromeProfile.integratedCorner,
        transparentBackground: transparentBackground,
        backgroundColor: connectedFrame
            ? Theme.of(context).fleurSurface.chrome
            : null,
        showRailDivider: !connectedFrame,
        presentationModeOverride: presentationModeOverride,
        showAccountSyncStatus: showAccountSyncStatus,
        currentUri: currentUri,
        railSurfaceStyle: shellChromeLayout.railSurfaceStyle,
        railWidth: shellChromeLayout.sidebarRailWidth,
        expandedWidth: expandedWidth ?? width,
      ),
    );
  }

  Widget _buildDesktopSecondaryLayer({
    required BuildContext context,
    required WidgetRef ref,
    required Size size,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required ShellChromeLayout shellChromeLayout,
    required double sidebarWidth,
    required double listWidth,
    required SidebarPresentationMode preferredNavigation,
    required AdaptiveWorkspaceArrangement arrangement,
    required NavigationHistoryState history,
  }) {
    final temporaryNavigationOpen = _temporarySidebarOpen;
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
      temporaryNavigationOpen: temporaryNavigationOpen,
      expandedNavigationWidth: sidebarWidth,
      railWidth: shellChromeLayout.sidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );
    final secondaryArrangement = AdaptiveWorkspaceArrangement(
      navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
      readerPresentation: WorkspaceReaderPresentation.secondaryPage,
      navigationTemporarilyCollapsed:
          arrangement.navigationPresentation !=
          WorkspaceNavigationPresentation.offCanvas,
      canExpandInline: arrangement.canExpandInline,
    );
    final updateManifest = ref.watch(
      appUpdateControllerProvider.select(
        (state) => state.hasUpdate ? state.manifest : null,
      ),
    );
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () {
        final result = WorkspaceNavigationToggleResult.resolve(
          presentation: WorkspaceNavigationPresentation.offCanvas,
          preferredNavigation: preferredNavigation,
          temporaryNavigationOpen: temporaryNavigationOpen,
          canExpandInline: false,
        );
        ref.read(sidebarPresentationModeProvider.notifier).state =
            result.preferredNavigation;
        if (result.temporaryNavigationOpen) {
          _openTemporarySidebar();
        } else {
          _closeTemporarySidebar();
        }
      },
      onSearch: () => _goToSearch(context),
    );
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      fallback: (shellChromeLayout.sidebarRailWidth - kShellControlSize) / 2,
    );
    final controlsRight =
        controlsLeft +
        _shellControlsGroupWidth(hasUpdate: updateManifest != null);
    final headerLeadingInset = shellChromeLayout.placesControlsInTitleBar
        ? 14.0
        : math.max(14.0, controlsRight - geometry.contentLeft + 12.0);
    return ShellSecondarySceneFrame(
      totalSize: size,
      geometry: geometry,
      shellChromeLayout: shellChromeLayout,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      sidebarWidth: sidebarWidth,
      listWidth: listWidth,
      preferredNavigation: preferredNavigation,
      arrangement: secondaryArrangement,
      titleBarCommands: commands.toTitleBarCommands(),
      controlsLeading: controlsLeft,
      headerLeadingInset: headerLeadingInset,
      updateManifest: updateManifest,
      navigationToggleFocusNode: _navigationToggleFocusNode,
      globalToolAreaKey: _globalToolAreaKey,
      temporaryNavigationFocusNode: _temporaryNavigationFocusNode,
      navigationPane: _desktopSidebar(
        context: context,
        width: kTemporaryWorkspaceSidebarWidth,
        showAccountSyncStatus: true,
        currentUri: widget.currentUri,
        shellChromeLayout: shellChromeLayout,
        presentationModeOverride: SidebarPresentationMode.expanded,
      ),
      onDismissNavigation: _closeTemporarySidebar,
      child: widget.child,
    );
  }

  Widget _buildSettingsShell({
    required BuildContext context,
    required WidgetRef ref,
    required Size size,
    required SidebarPresentationMode preferredNavigation,
    required AdaptiveWorkspaceArrangement arrangement,
    required bool canExpandInline,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required ShellChromeLayout shellChromeLayout,
    required double listWidth,
    required NavigationHistoryState history,
  }) {
    final railWidth = shellChromeLayout.sidebarRailWidth;
    final temporaryOpen = ref.watch(settingsTemporaryNavigationOpenProvider);
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: arrangement.navigationPresentation,
      temporaryNavigationOpen: temporaryOpen,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: railWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );
    final visibleLeftChromeWidth = temporaryOpen
        ? kTemporaryWorkspaceSidebarWidth
        : geometry.leftChromeWidth;
    final controlsPresentationMode =
        arrangement.navigationPresentation ==
                WorkspaceNavigationPresentation.expanded ||
            temporaryOpen
        ? SidebarPresentationMode.expanded
        : SidebarPresentationMode.collapsed;
    final updateManifest = ref.watch(
      appUpdateControllerProvider.select(
        (state) => state.hasUpdate ? state.manifest : null,
      ),
    );
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () => _toggleSettingsNavigation(
        ref,
        arrangement: arrangement,
        preferredNavigation: preferredNavigation,
        canExpandInline: canExpandInline,
      ),
      onSearch: () => _goToSearch(context),
    );
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      fallback: (railWidth - kShellControlSize) / 2,
    );
    final controlsRight =
        controlsLeft +
        _shellControlsGroupWidth(hasUpdate: updateManifest != null);
    final overlapWithContent = controlsRight - geometry.translatedContentLeft;
    final headerLeadingInset = shellChromeLayout.placesControlsInTitleBar
        ? 14.0
        : math.max(14.0, overlapWithContent + 12.0);
    final scope = ShellLayerScope(
      frameGeometry: geometry,
      totalSize: size,
      sidebarLayoutMode: sidebarLayoutModeForWidth(size.width),
      sidebarWidth: visibleLeftChromeWidth,
      listWidth: listWidth,
      headerLeadingInset: headerLeadingInset,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      navigationToggleFocusNode: _navigationToggleFocusNode,
      temporaryNavigationFocusNode: _temporaryNavigationFocusNode,
      preferredSidebarPresentationMode: preferredNavigation,
      workspaceArrangement: arrangement,
      child: AppDrawerScope(
        hasAppDrawer:
            arrangement.navigationPresentation !=
            WorkspaceNavigationPresentation.expanded,
        openDrawer: () => _toggleSettingsNavigation(
          ref,
          arrangement: arrangement,
          preferredNavigation: preferredNavigation,
          canExpandInline: canExpandInline,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: widget.child,
        ),
      ),
    );

    return _ShellHistoryShortcuts(
      commands: commands,
      onDismissNavigation: temporaryOpen
          ? () => _setSettingsTemporaryNavigation(ref, false)
          : null,
      child: AppMenuHost(
        child: ShellWindowFrame(
          geometry: geometry,
          shellChromeLayout: shellChromeLayout,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          titleBarCommands: commands.toTitleBarCommands(),
          controlsPresentationMode: controlsPresentationMode,
          searchSelected: false,
          updateManifest: updateManifest,
          controlsLeading: controlsLeft,
          navigationToggleFocusNode: _navigationToggleFocusNode,
          globalToolAreaKey: _globalToolAreaKey,
          child: scope,
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
    required bool canExpandInline,
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
    final collapsedRailWidth = shellChromeLayout.sidebarRailWidth;
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
    final shellShowsUpdate = updateManifest != null;
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      fallback: usesTitleBar
          ? ((collapsedRailWidth - kShellControlSize) / 2)
          : 12,
    );
    final controlsRight =
        controlsLeft + _shellControlsGroupWidth(hasUpdate: shellShowsUpdate);
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
    final contentSurfaceAppearance = WorkspaceLayerSurfaceAppearance.resolve(
      shellChromeLayout,
      floatingLeadingEdge: WorkspaceLayerEdge.level1,
    );
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () => _toggleResolvedNavigation(
        ref,
        arrangement: arrangement,
        preferredNavigation: preferredNavigation,
        canExpandInline: canExpandInline,
      ),
      onSearch: () => _goToSearch(context),
    );
    final sidebar = _desktopSidebar(
      key: const ValueKey('workspace-navigation-sidebar'),
      context: context,
      width: sidebarExpanded || temporarySidebarOpen
          ? visibleSidebarWidth
          : collapsedRailWidth,
      expandedWidth: sidebarWidth,
      showAccountSyncStatus: showAccountSyncStatus,
      currentUri: widget.currentUri,
      shellChromeLayout: shellChromeLayout,
      presentationModeOverride: sidebarExpanded || temporarySidebarOpen
          ? SidebarPresentationMode.expanded
          : SidebarPresentationMode.collapsed,
      transparentBackground: !sidebarExpanded && !temporarySidebarOpen,
    );
    final navigationPane = temporarySidebarOpen
        ? FocusScope.withExternalFocusNode(
            focusScopeNode: _temporaryNavigationFocusNode,
            autofocus: true,
            child: sidebar,
          )
        : sidebar;

    final contentLayer = ShellLayerScope(
      frameGeometry: geometry,
      totalSize: size,
      sidebarLayoutMode: sidebarLayoutMode,
      sidebarWidth: sidebarExpanded || temporarySidebarOpen
          ? visibleSidebarWidth
          : collapsedRailWidth,
      listWidth: listWidth,
      headerLeadingInset: headerLeadingInset,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      shellChromeLayout: shellChromeLayout,
      navigationToggleFocusNode: _navigationToggleFocusNode,
      temporaryNavigationFocusNode: _temporaryNavigationFocusNode,
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
      child: AppDrawerScope(
        hasAppDrawer: true,
        openDrawer: shellChromeLayout.profile == ShellChromeProfile.contentOnly
            ? commands.toggleSidebar
            : null,
        child: ShellWindowFrame(
          geometry: geometry,
          shellChromeLayout: shellChromeLayout,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          titleBarCommands: commands.toTitleBarCommands(),
          controlsPresentationMode: controlsPresentationMode,
          searchSelected: _isSearchRoute(widget.currentUri),
          updateManifest: shellShowsUpdate ? updateManifest : null,
          controlsLeading: controlsLeft,
          navigationToggleFocusNode: _navigationToggleFocusNode,
          globalToolAreaKey: _globalToolAreaKey,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AnimatedPositioned(
                duration: AppMotion.effectiveDuration(
                  context,
                  AppMotion.navigationTransitionDuration,
                ),
                curve: Curves.easeOutCubic,
                left: geometry.translatedContentLeft,
                top: 0,
                bottom: 0,
                width: geometry.contentWidth,
                child: ShellTemporarySceneGate(
                  navigationOpen: temporarySidebarOpen,
                  child: contentLayer,
                ),
              ),
              if (sidebarExpanded ||
                  temporarySidebarOpen ||
                  geometry.structuralRailVisible ||
                  geometry.railOverlayVisible)
                AnimatedPositioned(
                  duration: AppMotion.effectiveDuration(
                    context,
                    AppMotion.navigationTransitionDuration,
                  ),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: sidebarExpanded || temporarySidebarOpen
                      ? visibleSidebarWidth
                      : collapsedRailWidth,
                  child: navigationPane,
                ),
              if (sidebarExpanded) ...[
                Positioned(
                  key: const Key('app_shell_sidebar_split_handle'),
                  left: sidebarWidth - kWorkspaceSplitHandleHitWidth / 2,
                  top: 0,
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
              if (temporarySidebarOpen)
                Positioned(
                  key: const Key('app_shell_navigation_scrim'),
                  left: visibleSidebarWidth,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: ShellNavigationDismissScrim(
                    onDismiss: _closeTemporarySidebar,
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.12),
                  ),
                ),
            ],
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
    final settingsScene = _isSettingsRoute(widget.currentUri);
    final preferredNavigation = settingsScene
        ? ref.watch(settingsSidebarPresentationModeProvider)
        : ref.watch(sidebarPresentationModeProvider);
    final sidebarWidth = settingsScene
        ? kDefaultWorkspaceSidebarWidth
        : clampWorkspaceSidebarWidth(
            ref.watch(workspaceSidebarWidthProvider),
            size.width,
          );
    final shellChromeLayout = ShellChromeLayout.resolve();
    final preferredArticleListWidth =
        !settingsScene && _isArticleRoute(widget.currentUri)
        ? _listWidthForArticleUri(widget.currentUri)
        : null;
    final arrangementListWidth =
        preferredArticleListWidth ?? kCompactWorkspacePrimaryWidth;
    final layoutRequirements = settingsScene
        ? WorkspaceLayoutRequirements.settings
        : WorkspaceLayoutRequirements.feed(listWidth: arrangementListWidth);
    final arrangement = AdaptiveWorkspaceArrangement.resolve(
      totalWidth: size.width,
      preferredNavigation: preferredNavigation,
      navigationMetrics: shellChromeLayout.workspaceNavigationMetrics,
      requirements: layoutRequirements,
      hasReader: preferredArticleListWidth != null,
    );
    final canExpandInline = arrangement.canExpandInline;
    final railWidth = shellChromeLayout.sidebarRailWidth;
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

    if (settingsScene) {
      return ShellSceneScope(
        activeScene: ShellSceneKind.settings,
        child: _buildSettingsShell(
          context: context,
          ref: ref,
          size: size,
          preferredNavigation: preferredNavigation,
          arrangement: arrangement,
          canExpandInline: canExpandInline,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          shellChromeLayout: shellChromeLayout,
          listWidth: listWidth,
          history: history,
        ),
      );
    }

    if (hideNavForReaderPage) {
      return ShellSceneScope(
        activeScene: ShellSceneKind.workspace,
        child: _ShellHistoryShortcuts(
          commands: shortcutCommands,
          onDismissNavigation: _temporarySidebarOpen
              ? _closeTemporarySidebar
              : null,
          child: _buildDesktopSecondaryLayer(
            context: context,
            ref: ref,
            size: size,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            shellChromeLayout: shellChromeLayout,
            sidebarWidth: sidebarWidth,
            listWidth: listWidth,
            preferredNavigation: preferredNavigation,
            arrangement: arrangement,
            history: history,
          ),
        ),
      );
    }

    return ShellSceneScope(
      activeScene: ShellSceneKind.workspace,
      child: _ShellHistoryShortcuts(
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
          canExpandInline: canExpandInline,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          shellChromeLayout: shellChromeLayout,
          surfaces: surfaces,
          sidebarWidth: sidebarWidth,
          listWidth: listWidth,
          history: history,
        ),
      ),
    );
  }
}

const double _kSidebarCollapseThresholdWidth = kMinWorkspaceSidebarWidth / 2;

double _shellControlsGroupWidth({required bool hasUpdate}) {
  const baseControlCount = 4;
  return kShellControlSize * (baseControlCount + (hasUpdate ? 1 : 0));
}
