import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/app_update_providers.dart';
import '../providers/core_providers.dart';
import '../providers/navigation_history_provider.dart';
import '../services/update/app_update_manifest.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/update/app_update_dialog.dart';
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
  bool _navigationHistoryBindScheduled = false;
  double? _sidebarResizeVirtualWidth;
  GoRouter? _pendingNavigationHistoryRouter;

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
    return shouldEmbedReaderForLayout(
      spec,
      listWidth: _listWidthForArticleUri(uri),
    );
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

  Widget _sidebarDrawer(
    BuildContext context, {
    required bool showAccountSyncStatus,
    required Uri currentUri,
  }) {
    return Drawer(
      child: SafeArea(
        child: Sidebar(
          onSelectScope: (scope) => _goToScope(context, scope),
          router: GoRouter.maybeOf(context),
          presentationModeOverride: SidebarPresentationMode.expanded,
          showAccountSyncStatus: showAccountSyncStatus,
          currentUri: currentUri,
        ),
      ),
    );
  }

  Widget _desktopSidebar({
    required BuildContext context,
    required double width,
    required bool showAccountSyncStatus,
    required Uri currentUri,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    VoidCallback? onSearch,
    SidebarPresentationMode? presentationModeOverride,
  }) {
    return SizedBox(
      width: width,
      child: Sidebar(
        onSelectScope: (scope) => _goToScope(context, scope),
        reserveShellHeader: isDesktop,
        presentationModeOverride: presentationModeOverride,
        showAccountSyncStatus: showAccountSyncStatus,
        currentUri: currentUri,
        onSearch: onSearch,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
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
    required bool searchSelected,
    required NavigationHistoryState history,
    required AppUpdateManifest? updateManifest,
  }) {
    if (!isDesktop) return child;
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: () =>
          _toggleSidebar(ref, usesTemporarySidebar: usesTemporarySidebar),
      onSearch: () => _goToSearch(context),
    );
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: _shellControlsLeftInset(macOSWindowChromeMetrics, fallback: 12),
          top: _shellControlsTopInset(macOSWindowChromeMetrics),
          child: _InlineShellControlsHost(
            presentationMode: presentationMode,
            commands: commands,
            searchSelected: searchSelected,
            updateManifest: updateManifest,
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
    required NavigationHistoryState history,
    bool useTemporarySidebarControls = false,
  }) {
    final sidebarLayoutMode = sidebarLayoutModeForWidth(size.width);
    final hasInlineSidebar = sidebarLayoutMode == SidebarLayoutMode.inline;
    final sidebarExpanded =
        hasInlineSidebar &&
        presentationMode == SidebarPresentationMode.expanded;
    final usesTemporarySidebar =
        !hasInlineSidebar || useTemporarySidebarControls;
    final temporarySidebarOpen = usesTemporarySidebar && _temporarySidebarOpen;
    final visibleSidebarWidth = temporarySidebarOpen
        ? kTemporaryWorkspaceSidebarWidth
        : sidebarWidth;
    final contentLeft = sidebarExpanded
        ? sidebarWidth + kSidebarContentDividerWidth
        : (temporarySidebarOpen ? visibleSidebarWidth : 0.0);
    final contentWidth = sidebarExpanded
        ? (size.width - contentLeft).clamp(0.0, double.infinity).toDouble()
        : size.width;
    final railOverlayVisible = !sidebarExpanded && !temporarySidebarOpen;
    final contentLeadingInset = railOverlayVisible
        ? kSidebarRailWidth + kRailOverlayContentGap
        : 0.0;
    final controlsPresentationMode = sidebarExpanded || temporarySidebarOpen
        ? SidebarPresentationMode.expanded
        : SidebarPresentationMode.collapsed;
    final updateManifest = ref.watch(
      appUpdateControllerProvider.select(
        (state) => state.hasUpdate ? state.manifest : null,
      ),
    );
    final controlsLeft = _shellControlsLeftInset(
      macOSWindowChromeMetrics,
      fallback: 12,
    );
    final controlsRight =
        controlsLeft +
        _shellControlsGroupWidth(
          controlsPresentationMode,
          hasUpdate: updateManifest != null,
        );
    final overlapWithContent = controlsRight - contentLeft;
    final headerLeadingInset = overlapWithContent > 0
        ? overlapWithContent + 8
        : 14.0;
    final contentLayoutSpec = LayoutSpec.fromContentSize(
      contentWidth: contentWidth,
      contentHeight: size.height,
      listWidth: listWidth,
    );
    final showAccountSyncStatus = !contentLayoutSpec.showsListSyncStatusCapsule;

    final contentLayer = ShellLayerScope(
      totalSize: size,
      contentSize: Size(contentWidth, size.height),
      sidebarLayoutMode: sidebarLayoutMode,
      contentLeft: contentLeft,
      contentLeadingInset: contentLeadingInset,
      railOverlayVisible: railOverlayVisible,
      sidebarWidth: visibleSidebarWidth,
      listWidth: listWidth,
      headerLeadingInset: headerLeadingInset,
      macOSWindowChromeMetrics: macOSWindowChromeMetrics,
      child: WorkspaceLayerSurface(
        key: const Key('app_shell_content_layer'),
        color: surfaces.list,
        leadingEdge: WorkspaceLayerEdge.level1,
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
          child: _withDesktopShellControlsOverlay(
            context: context,
            ref: ref,
            presentationMode: controlsPresentationMode,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            usesTemporarySidebar: usesTemporarySidebar,
            searchSelected: _isSearchRoute(widget.currentUri),
            history: history,
            updateManifest: updateManifest,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: visibleSidebarWidth,
                  child: _desktopSidebar(
                    context: context,
                    width: visibleSidebarWidth,
                    showAccountSyncStatus: showAccountSyncStatus,
                    currentUri: widget.currentUri,
                    macOSWindowChromeMetrics: macOSWindowChromeMetrics,
                    onSearch: sidebarExpanded || temporarySidebarOpen
                        ? () => _goToSearch(context)
                        : null,
                    presentationModeOverride: SidebarPresentationMode.expanded,
                  ),
                ),
                if (sidebarExpanded) ...[
                  Positioned(
                    key: const Key('app_shell_sidebar_split_handle'),
                    left: sidebarWidth - kWorkspaceSplitHandleHitWidth / 2,
                    top: kWorkspaceHeaderHeight,
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
                  left: contentLeft,
                  top: 0,
                  bottom: 0,
                  width: contentWidth,
                  child: contentLayer,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: kSidebarRailWidth,
                  child: _RailOverlayHost(
                    visible: railOverlayVisible,
                    delay: _kContentLayerAnimationDuration,
                    child: Sidebar(
                      onSelectScope: (scope) => _goToScope(context, scope),
                      reserveShellHeader: true,
                      transparentBackground: true,
                      presentationModeOverride:
                          SidebarPresentationMode.collapsed,
                      showAccountSyncStatus: showAccountSyncStatus,
                      currentUri: widget.currentUri,
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

  Widget _withDesktopDrawerControlsOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required VoidCallback? openDrawer,
    required MacOSWindowChromeMetrics macOSWindowChromeMetrics,
    required NavigationHistoryState history,
  }) {
    if (!isDesktop || openDrawer == null) return child;
    final commands = ShellNavigationCommands(
      context: context,
      router: GoRouter.maybeOf(context),
      history: history,
      historyController: ref.read(navigationHistoryControllerProvider.notifier),
      onToggleSidebar: openDrawer,
      onSearch: () => _goToSearch(context),
    );
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          top: 0,
          child: _DrawerControlsHost(
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            commands: commands,
          ),
        ),
      ],
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
    final presentationMode = ref.watch(sidebarPresentationModeProvider);
    final sidebarWidth = clampWorkspaceSidebarWidth(
      ref.watch(workspaceSidebarWidthProvider),
      size.width,
    );
    final sidebarLayoutMode = sidebarLayoutModeForWidth(size.width);
    final preferredArticleListWidth = _isArticleRoute(widget.currentUri)
        ? _listWidthForArticleUri(widget.currentUri)
        : null;
    final baseSidebarPresentationMode =
        sidebarLayoutMode == SidebarLayoutMode.inline
        ? presentationMode
        : SidebarPresentationMode.collapsed;
    var effectiveSidebarPresentationMode = baseSidebarPresentationMode;
    var useTemporarySidebarControls = false;

    if (preferredArticleListWidth != null &&
        baseSidebarPresentationMode == SidebarPresentationMode.expanded) {
      final expandedSpec = LayoutSpec.fromTotalSize(
        totalWidth: size.width,
        totalHeight: size.height,
        sidebarPresentationMode: baseSidebarPresentationMode,
        sidebarWidth: sidebarWidth,
        listWidth: preferredArticleListWidth,
      );
      if (shouldCollapseSidebarForReaderLayout(
        expandedSpec,
        preferredListWidth: preferredArticleListWidth,
      )) {
        effectiveSidebarPresentationMode = SidebarPresentationMode.collapsed;
        useTemporarySidebarControls = true;
      }
    }

    final contentWidthForList = effectiveContentWidth(
      size.width,
      sidebarPresentationMode: effectiveSidebarPresentationMode,
      sidebarWidth: sidebarWidth,
    );
    final listWidth = clampWorkspaceListWidth(
      ref.watch(workspaceListWidthProvider),
      contentWidthForList,
    );
    final macOSWindowChromeMetrics = ref.watch(
      macOSWindowChromeMetricsProvider,
    );
    final spec = LayoutSpec.fromTotalSize(
      totalWidth: size.width,
      totalHeight: size.height,
      sidebarPresentationMode: effectiveSidebarPresentationMode,
      sidebarWidth: sidebarWidth,
      listWidth: listWidth,
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
        return _ShellHistoryShortcuts(
          commands: shortcutCommands,
          child: _buildDesktopSecondaryLayer(
            context: context,
            size: size,
            surfaces: surfaces,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            sidebarWidth: sidebarWidth,
            listWidth: listWidth,
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

    if (isDesktop) {
      return _ShellHistoryShortcuts(
        commands: shortcutCommands,
        child: _buildDesktopLayeredShell(
          context: context,
          ref: ref,
          size: size,
          presentationMode: effectiveSidebarPresentationMode,
          macOSWindowChromeMetrics: macOSWindowChromeMetrics,
          surfaces: surfaces,
          sidebarWidth: sidebarWidth,
          listWidth: listWidth,
          history: history,
          useTemporarySidebarControls: useTemporarySidebarControls,
        ),
      );
    }

    return _ShellHistoryShortcuts(
      commands: shortcutCommands,
      child: wrapShell(
        Scaffold(
          drawer: _sidebarDrawer(
            context,
            showAccountSyncStatus: !spec.showsListSyncStatusCapsule,
            currentUri: widget.currentUri,
          ),
          body: Builder(
            builder: (scaffoldContext) {
              void openDrawer() => Scaffold.of(scaffoldContext).openDrawer();

              return AppDrawerScope(
                hasAppDrawer: true,
                openDrawer: openDrawer,
                child: _withDesktopDrawerControlsOverlay(
                  context: context,
                  ref: ref,
                  openDrawer: openDrawer,
                  macOSWindowChromeMetrics: macOSWindowChromeMetrics,
                  history: history,
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
      ),
    );
  }
}

const _kContentLayerAnimationDuration = Duration(milliseconds: 180);
const double _kSidebarCollapseThresholdWidth = kMinWorkspaceSidebarWidth / 2;

double _shellControlsGroupWidth(
  SidebarPresentationMode mode, {
  required bool hasUpdate,
}) {
  final baseControlCount = mode == SidebarPresentationMode.expanded ? 3 : 4;
  return kShellControlSize * (baseControlCount + (hasUpdate ? 1 : 0));
}

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
}

class _ShellHistoryBackIntent extends Intent {
  const _ShellHistoryBackIntent();
}

class _ShellHistoryForwardIntent extends Intent {
  const _ShellHistoryForwardIntent();
}

class _ShellHistoryShortcuts extends StatelessWidget {
  const _ShellHistoryShortcuts({required this.commands, required this.child});

  final ShellNavigationCommands commands;
  final Widget child;

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
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _InlineShellControlsHost extends StatelessWidget {
  const _InlineShellControlsHost({
    required this.presentationMode,
    required this.commands,
    required this.searchSelected,
    required this.updateManifest,
  });

  final SidebarPresentationMode presentationMode;
  final ShellNavigationCommands commands;
  final bool searchSelected;
  final AppUpdateManifest? updateManifest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final updateManifest = this.updateManifest;
    final controls = [
      _ShellControlData(
        key: const Key('shell_sidebar_button'),
        tooltip: sidebarExpanded ? l10n.collapse : l10n.expand,
        onPressed: commands.toggleSidebar,
        icon: sidebarExpanded
            ? FleurIcons.sidebarCollapse
            : FleurIcons.sidebarExpand,
      ),
      _ShellControlData(
        key: const Key('shell_back_button'),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: commands.canGoBack ? commands.goBack : null,
        icon: FleurIcons.back,
      ),
      _ShellControlData(
        key: const Key('shell_forward_button'),
        tooltip: AppLocalizations.of(context)!.forward,
        onPressed: commands.canGoForward ? commands.goForward : null,
        icon: FleurIcons.forward,
      ),
      if (updateManifest != null)
        _ShellControlData(
          key: const Key('shell_update_button'),
          tooltip: l10n.updateAvailable,
          onPressed: () {
            unawaited(showAppUpdateDialog(context, manifest: updateManifest));
          },
          icon: FleurIcons.download,
          selected: true,
        ),
      if (!sidebarExpanded)
        _ShellControlData(
          key: const Key('shell_search_button'),
          tooltip: l10n.search,
          onPressed: commands.goToSearch,
          icon: searchSelected ? FleurIcons.searchSelected : FleurIcons.search,
          selected: searchSelected,
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
              selected: control.selected,
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
    this.selected = false,
  });

  final Key key;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;
}

class _DrawerControlsHost extends StatelessWidget {
  const _DrawerControlsHost({
    required this.macOSWindowChromeMetrics,
    required this.commands,
  });

  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final ShellNavigationCommands commands;

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
              onPressed: commands.toggleSidebar,
              icon: FleurIcons.sidebarExpand,
            ),
            _DrawerControlButton(
              key: const Key('shell_back_button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: commands.canGoBack ? commands.goBack : null,
              icon: FleurIcons.back,
            ),
            _DrawerControlButton(
              key: const Key('shell_forward_button'),
              tooltip: l10n.forward,
              onPressed: commands.canGoForward ? commands.goForward : null,
              icon: FleurIcons.forward,
            ),
            _DrawerControlButton(
              key: const Key('shell_search_button'),
              tooltip: l10n.search,
              onPressed: commands.goToSearch,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final disabledOpacity = theme.brightness == Brightness.dark ? 0.22 : 0.28;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: kShellControlIconSize),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(kShellControlSize)),
        minimumSize: const WidgetStatePropertyAll(
          Size.square(kShellControlSize),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((stateSet) {
          if (stateSet.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: disabledOpacity);
          }
          return scheme.onSurfaceVariant;
        }),
        overlayColor: WidgetStateProperty.resolveWith((stateSet) {
          if (stateSet.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (stateSet.contains(WidgetState.pressed)) return states.pressedTint;
          if (stateSet.contains(WidgetState.hovered) ||
              stateSet.contains(WidgetState.focused)) {
            return states.hoverTint;
          }
          return null;
        }),
      ),
    );
  }
}
