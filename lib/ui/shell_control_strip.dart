import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../services/update/app_update_manifest.dart';
import '../theme/fleur_icons.dart';
import '../widgets/fleur_capsule_button_group.dart';
import '../widgets/fleur_selection_transition.dart';
import '../widgets/fleur_shell_icon_button.dart';
import 'sidebar_layout.dart';
import 'update/app_update_dialog.dart';

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

enum ShellControlStripSurface { flat, capsule }

class ShellControlStrip extends StatelessWidget {
  const ShellControlStrip({
    super.key,
    required this.commands,
    required this.presentationMode,
    required this.surface,
    this.searchSelected = false,
    this.showSearch = true,
    this.updateManifest,
    this.updateBeforeSearch = false,
    this.navigationToggleFocusNode,
  });

  final ShellWindowTitleBarCommands commands;
  final SidebarPresentationMode presentationMode;
  final ShellControlStripSurface surface;
  final bool searchSelected;
  final bool showSearch;
  final AppUpdateManifest? updateManifest;
  final bool updateBeforeSearch;
  final FocusNode? navigationToggleFocusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final controls = <_ShellControlData>[
      _ShellControlData(
        key: const Key('shell_sidebar_button'),
        tooltip: sidebarExpanded ? l10n.collapse : l10n.expand,
        onPressed: commands.onToggleSidebar,
        icon: sidebarExpanded
            ? FleurIcons.sidebarCollapse
            : FleurIcons.sidebarExpand,
        focusNode: navigationToggleFocusNode,
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
      if (updateBeforeSearch) ..._updateControl(context, l10n),
      if (showSearch)
        _ShellControlData(
          key: const Key('shell_search_button'),
          tooltip: l10n.search,
          onPressed: commands.onSearch,
          icon: searchSelected ? FleurIcons.searchSelected : FleurIcons.search,
          selected: searchSelected,
        ),
      if (!updateBeforeSearch) ..._updateControl(context, l10n),
    ];

    if (surface == ShellControlStripSurface.capsule) {
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
              focusNode: control.focusNode,
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final control in controls)
          _FlatShellControlButton(
            key: control.key,
            tooltip: control.tooltip,
            onPressed: control.onPressed,
            icon: control.icon,
            selected: control.selected,
            focusNode: control.focusNode,
          ),
      ],
    );
  }

  List<_ShellControlData> _updateControl(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final manifest = updateManifest;
    if (manifest == null) return const [];
    return [
      _ShellControlData(
        key: const Key('shell_update_button'),
        tooltip: l10n.updateAvailable,
        onPressed: () {
          unawaited(showAppUpdateDialog(context, manifest: manifest));
        },
        icon: FleurIcons.download,
        selected: true,
      ),
    ];
  }
}

class _ShellControlData {
  const _ShellControlData({
    required this.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
    this.focusNode,
  });

  final Key key;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;
  final FocusNode? focusNode;
}

class _FlatShellControlButton extends StatelessWidget {
  const _FlatShellControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.selected,
    this.focusNode,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool selected;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledOpacity = theme.brightness == Brightness.dark ? 0.22 : 0.28;
    return IconButton(
      focusNode: focusNode,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: FleurAnimatedIcon(icon: icon, size: kShellControlIconSize),
      style: FleurShellIconButtonStyle.styleFor(
        context,
        selected: selected,
        size: kShellControlSize,
        disabledOpacity: disabledOpacity,
      ),
    );
  }
}
