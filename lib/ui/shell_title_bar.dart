import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../services/update/app_update_manifest.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import 'shell_chrome_layout.dart';
import 'sidebar_layout.dart';
import 'update/app_update_dialog.dart';
import 'workspace_layers.dart';

class ShellWindowTitleBarCommands {
  const ShellWindowTitleBarCommands({
    required this.onToggleSidebar,
    required this.onBack,
    required this.onForward,
    required this.onSearch,
    required this.canGoBack,
    required this.canGoForward,
  });

  final VoidCallback onToggleSidebar;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onSearch;
  final bool canGoBack;
  final bool canGoForward;
}

class ShellWindowTitleBar extends StatelessWidget {
  const ShellWindowTitleBar({
    super.key,
    this.commands,
    this.presentationMode = SidebarPresentationMode.expanded,
    this.searchSelected = false,
    this.updateManifest,
    this.leadingLeft = 0,
    this.dividerLeadingInset = 0,
  });

  final ShellWindowTitleBarCommands? commands;
  final SidebarPresentationMode presentationMode;
  final bool searchSelected;
  final AppUpdateManifest? updateManifest;
  final double leadingLeft;
  final double dividerLeadingInset;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final commands = this.commands;

    return Material(
      key: const Key('shell_title_bar'),
      color: surfaces.chrome,
      child: SizedBox(
        height: kWorkspaceHeaderHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: WindowDragSurface(
                key: Key('shell_title_bar_drag_surface'),
              ),
            ),
            if (commands != null)
              Positioned(
                left: leadingLeft,
                top: kShellControlTopInset,
                height: kShellControlSize,
                child: _ShellWindowControlsHost(
                  presentationMode: presentationMode,
                  commands: commands,
                  searchSelected: searchSelected,
                  updateManifest: updateManifest,
                ),
              ),
            const Positioned(
              key: Key('shell_window_caption_controls_host'),
              top: 0,
              right: 0,
              height: kWorkspaceHeaderHeight,
              width: kShellWindowCaptionControlsWidth,
              child: _WindowCaptionControls(),
            ),
            Positioned(
              left: dividerLeadingInset,
              right: 0,
              bottom: 0,
              height: 1,
              child: ColoredBox(
                key: const Key('shell_title_bar_divider'),
                color: surfaces.subtleDivider,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellWindowControlsHost extends StatelessWidget {
  const _ShellWindowControlsHost({
    required this.presentationMode,
    required this.commands,
    required this.searchSelected,
    required this.updateManifest,
  });

  final SidebarPresentationMode presentationMode;
  final ShellWindowTitleBarCommands commands;
  final bool searchSelected;
  final AppUpdateManifest? updateManifest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final controls = [
      _ShellControlData(
        key: const Key('shell_sidebar_button'),
        tooltip: sidebarExpanded ? l10n.collapse : l10n.expand,
        onPressed: commands.onToggleSidebar,
        icon: sidebarExpanded
            ? FleurIcons.sidebarCollapse
            : FleurIcons.sidebarExpand,
      ),
      _ShellControlData(
        key: const Key('shell_back_button'),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: commands.canGoBack ? commands.onBack : null,
        icon: FleurIcons.back,
      ),
      _ShellControlData(
        key: const Key('shell_forward_button'),
        tooltip: l10n.forward,
        onPressed: commands.canGoForward ? commands.onForward : null,
        icon: FleurIcons.forward,
      ),
      _ShellControlData(
        key: const Key('shell_search_button'),
        tooltip: l10n.search,
        onPressed: commands.onSearch,
        icon: searchSelected ? FleurIcons.searchSelected : FleurIcons.search,
        selected: searchSelected,
      ),
      if (updateManifest != null)
        _ShellControlData(
          key: const Key('shell_update_button'),
          tooltip: l10n.updateAvailable,
          onPressed: () {
            unawaited(showAppUpdateDialog(context, manifest: updateManifest!));
          },
          icon: FleurIcons.download,
          selected: true,
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final control in controls)
          _ShellControlButton(
            key: control.key,
            tooltip: control.tooltip,
            onPressed: control.onPressed,
            icon: control.icon,
            selected: control.selected,
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

class _ShellControlButton extends StatelessWidget {
  const _ShellControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;

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
        foregroundColor: WidgetStateProperty.resolveWith((widgetStates) {
          if (widgetStates.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: disabledOpacity);
          }
          if (selected) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((widgetStates) {
          if (selected) return states.selectionTint;
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.resolveWith((widgetStates) {
          if (widgetStates.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (widgetStates.contains(WidgetState.pressed)) {
            return states.pressedTint;
          }
          if (widgetStates.contains(WidgetState.hovered) ||
              widgetStates.contains(WidgetState.focused)) {
            return states.hoverTint;
          }
          return null;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _WindowCaptionControls extends StatefulWidget {
  const _WindowCaptionControls();

  @override
  State<_WindowCaptionControls> createState() => _WindowCaptionControlsState();
}

class _WindowCaptionControlsState extends State<_WindowCaptionControls>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncMaximized());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (!mounted) return;
      setState(() => _maximized = maximized);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _minimize() async {
    try {
      await windowManager.minimize();
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _toggleMaximized() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
      await _syncMaximized();
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _close() async {
    try {
      await windowManager.close();
    } on MissingPluginException {
      return;
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      key: const Key('shell_window_caption_controls'),
      height: kWorkspaceHeaderHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CaptionButtonSlot(
            child: WindowCaptionButton.minimize(
              key: const Key('shell_window_minimize_button'),
              brightness: brightness,
              onPressed: () => unawaited(_minimize()),
            ),
          ),
          if (_maximized)
            _CaptionButtonSlot(
              child: WindowCaptionButton.unmaximize(
                key: const Key('shell_window_maximize_button'),
                brightness: brightness,
                onPressed: () => unawaited(_toggleMaximized()),
              ),
            )
          else
            _CaptionButtonSlot(
              child: WindowCaptionButton.maximize(
                key: const Key('shell_window_maximize_button'),
                brightness: brightness,
                onPressed: () => unawaited(_toggleMaximized()),
              ),
            ),
          _CaptionButtonSlot(
            child: WindowCaptionButton.close(
              key: const Key('shell_window_close_button'),
              brightness: brightness,
              onPressed: () => unawaited(_close()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionButtonSlot extends StatelessWidget {
  const _CaptionButtonSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kShellWindowCaptionButtonWidth,
      height: kWorkspaceHeaderHeight,
      child: child,
    );
  }
}
