part of 'app_shell.dart';

extension _AppShellNavigationToggleActions on _AppShellState {
  void _toggleResolvedNavigation(
    WidgetRef ref, {
    required AdaptiveWorkspaceArrangement arrangement,
    required SidebarPresentationMode preferredNavigation,
    required bool canExpandInline,
  }) {
    final result = WorkspaceNavigationToggleResult.resolve(
      presentation: arrangement.navigationPresentation,
      preferredNavigation: preferredNavigation,
      temporaryNavigationOpen: _temporarySidebarOpen,
      canExpandInline: canExpandInline,
    );
    ref.read(sidebarPresentationModeProvider.notifier).state =
        result.preferredNavigation;
    if (result.temporaryNavigationOpen) {
      _openTemporarySidebar();
    } else {
      _closeTemporarySidebar();
    }
  }

  void _toggleSettingsNavigation(
    WidgetRef ref, {
    required AdaptiveWorkspaceArrangement arrangement,
    required SidebarPresentationMode preferredNavigation,
    required bool canExpandInline,
  }) {
    final openNotifier = ref.read(
      settingsTemporaryNavigationOpenProvider.notifier,
    );
    final result = WorkspaceNavigationToggleResult.resolve(
      presentation: arrangement.navigationPresentation,
      preferredNavigation: preferredNavigation,
      temporaryNavigationOpen: openNotifier.state,
      canExpandInline: canExpandInline,
    );
    ref.read(settingsSidebarPresentationModeProvider.notifier).state =
        result.preferredNavigation;
    _setSettingsTemporaryNavigation(ref, result.temporaryNavigationOpen);
  }
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
        duration: AppMotion.effectiveDuration(
          context,
          const Duration(milliseconds: 90),
        ),
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
    final result = Shortcuts(
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
    final dismissNavigation = onDismissNavigation;
    if (dismissNavigation == null) return result;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) dismissNavigation();
      },
      child: result,
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
