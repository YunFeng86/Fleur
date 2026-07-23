import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../services/update/app_update_manifest.dart';
import '../theme/fleur_theme_extensions.dart';
import 'design_system/controls/fleur_shell_icon_button.dart';
import 'shell_chrome_layout.dart';
import 'shell_control_strip.dart';
import 'shell_frame_topology.dart';
import 'shell_global_tool_area.dart';
import 'sidebar_layout.dart';
import 'workspace_layers.dart';

export 'shell_control_strip.dart' show ShellWindowTitleBarCommands;

const double kShellTitleBarMinimumDragWidth = 48;

class ShellWindowTitleBar extends StatelessWidget {
  const ShellWindowTitleBar({
    super.key,
    this.commands,
    this.presentationMode = SidebarPresentationMode.expanded,
    this.searchSelected = false,
    this.showSearch = true,
    this.updateManifest,
    this.globalToolAreaKey,
    this.leadingLeft = 0,
    this.dividerLeadingInset = 0,
    this.navigationToggleFocusNode,
  });

  final ShellWindowTitleBarCommands? commands;
  final SidebarPresentationMode presentationMode;
  final bool searchSelected;
  final bool showSearch;
  final AppUpdateManifest? updateManifest;
  final Key? globalToolAreaKey;
  final double leadingLeft;
  final double dividerLeadingInset;
  final FocusNode? navigationToggleFocusNode;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final commands = this.commands;

    return Material(
      key: const Key('shell_title_bar'),
      color: surfaces.chrome,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controlsWidth =
              (constraints.maxWidth -
                      leadingLeft -
                      kShellWindowCaptionControlsWidth -
                      kShellTitleBarMinimumDragWidth)
                  .clamp(0.0, double.infinity)
                  .toDouble();
          return SizedBox(
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
                  _AdaptiveShellWindowControlsHost(
                    left: leadingLeft,
                    width: controlsWidth,
                    presentationMode: presentationMode,
                    commands: commands,
                    searchSelected: searchSelected,
                    showSearch: showSearch,
                    updateManifest: updateManifest,
                    globalToolAreaKey: globalToolAreaKey,
                    navigationToggleFocusNode: navigationToggleFocusNode,
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
          );
        },
      ),
    );
  }
}

class _AdaptiveShellWindowControlsHost extends StatefulWidget {
  const _AdaptiveShellWindowControlsHost({
    required this.left,
    required this.width,
    required this.presentationMode,
    required this.commands,
    required this.searchSelected,
    required this.showSearch,
    required this.updateManifest,
    required this.globalToolAreaKey,
    required this.navigationToggleFocusNode,
  });

  final double left;
  final double width;
  final SidebarPresentationMode presentationMode;
  final ShellWindowTitleBarCommands commands;
  final bool searchSelected;
  final bool showSearch;
  final AppUpdateManifest? updateManifest;
  final Key? globalToolAreaKey;
  final FocusNode? navigationToggleFocusNode;

  @override
  State<_AdaptiveShellWindowControlsHost> createState() =>
      _AdaptiveShellWindowControlsHostState();
}

class _AdaptiveShellWindowControlsHostState
    extends State<_AdaptiveShellWindowControlsHost> {
  late FocusHighlightMode _interactionMode;

  @override
  void initState() {
    super.initState();
    _interactionMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleInteractionMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleInteractionMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetExtent = FleurShellIconButtonStyle.tapTargetExtent(
      size: kShellControlSize,
      adaptiveTapTarget: true,
      interactionMode: _interactionMode,
    );
    return Positioned(
      left: widget.left,
      top: (kWorkspaceHeaderHeight - targetExtent) / 2,
      width: widget.width,
      height: targetExtent,
      child: _ShellWindowControlsHost(
        presentationMode: widget.presentationMode,
        commands: widget.commands,
        searchSelected: widget.searchSelected,
        showSearch: widget.showSearch,
        updateManifest: widget.updateManifest,
        globalToolAreaKey: widget.globalToolAreaKey,
        navigationToggleFocusNode: widget.navigationToggleFocusNode,
        availableWidth: widget.width,
        adaptiveTapTargets: true,
        interactionMode: _interactionMode,
      ),
    );
  }

  void _handleInteractionMode(FocusHighlightMode value) {
    if (_interactionMode == value) return;
    setState(() => _interactionMode = value);
  }
}

class _ShellWindowControlsHost extends StatelessWidget {
  const _ShellWindowControlsHost({
    required this.presentationMode,
    required this.commands,
    required this.searchSelected,
    required this.showSearch,
    required this.updateManifest,
    required this.globalToolAreaKey,
    required this.navigationToggleFocusNode,
    required this.availableWidth,
    required this.adaptiveTapTargets,
    required this.interactionMode,
  });

  final SidebarPresentationMode presentationMode;
  final ShellWindowTitleBarCommands commands;
  final bool searchSelected;
  final bool showSearch;
  final AppUpdateManifest? updateManifest;
  final Key? globalToolAreaKey;
  final FocusNode? navigationToggleFocusNode;
  final double availableWidth;
  final bool adaptiveTapTargets;
  final FocusHighlightMode interactionMode;

  @override
  Widget build(BuildContext context) {
    return ShellGlobalToolArea(
      key: globalToolAreaKey,
      commands: commands,
      presentationMode: presentationMode,
      surface: ShellGlobalToolSurface.windowFrame,
      searchSelected: searchSelected,
      showSearch: showSearch,
      updateManifest: updateManifest,
      navigationToggleFocusNode: navigationToggleFocusNode,
      availableWidth: availableWidth,
      adaptiveTapTargets: adaptiveTapTargets,
      interactionMode: interactionMode,
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
