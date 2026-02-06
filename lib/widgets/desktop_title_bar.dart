import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/platform.dart';

class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.height = AppTheme.desktopTitleBarHeight,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final double height;

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!isDesktop) return;
    windowManager.addListener(this);
    unawaited(_syncMaximized());
  }

  @override
  void dispose() {
    if (isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _syncMaximized() async {
    final v = await windowManager.isMaximized();
    if (!mounted) return;
    setState(() => _isMaximized = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final centerTitle = defaultTargetPlatform == TargetPlatform.macOS;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: cs.surface,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the title truly centered in the *full* title bar width.
            // A plain Row/Expanded centers relative to the remaining space
            // after leading/actions, which looks visually off on macOS when
            // traffic lights + actions are asymmetric.
            final leftReserved =
                (isMacOS ? 72.0 : 0.0) + (widget.leading == null ? 0.0 : 48.0);
            final rightReserved =
                (widget.actions.length * 48.0) + (isMacOS ? 0.0 : 46.0 * 3);
            final sideReserved = centerTitle
                ? (leftReserved > rightReserved ? leftReserved : rightReserved)
                : 0.0;
            final leftPadding = centerTitle
                ? sideReserved + 12
                : leftReserved + 12;
            final rightPadding = centerTitle
                ? sideReserved + 12
                : rightReserved + 12;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Center title + drag region (padded to avoid overlapping
                // interactive controls on either side).
                Positioned.fill(
                  child: DragToMoveArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: leftPadding,
                        right: rightPadding,
                      ),
                      child: Align(
                        alignment: centerTitle
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: centerTitle ? TextAlign.center : null,
                          style: titleStyle,
                        ),
                      ),
                    ),
                  ),
                ),
                // Leading region (traffic lights safe area + optional button).
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMacOS) const SizedBox(width: 72),
                      if (widget.leading != null) widget.leading!,
                    ],
                  ),
                ),
                // Actions + window buttons on the right.
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.actions,
                      if (!isMacOS) _WindowButtons(isMaximized: _isMaximized),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons({required this.isMaximized});

  final bool isMaximized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    Widget btn({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      Color? hover,
    }) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: onPressed,
          hoverColor: hover ?? cs.primary.withAlpha(31),
          child: SizedBox(
            width: 46,
            height: double.infinity,
            child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(
          icon: Icons.remove,
          tooltip: l10n.windowMinimize,
          onPressed: () => windowManager.minimize(),
        ),
        btn(
          icon: isMaximized ? Icons.filter_none : Icons.crop_square,
          tooltip: isMaximized ? l10n.windowRestore : l10n.windowMaximize,
          onPressed: () async {
            final v = await windowManager.isMaximized();
            if (v) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        btn(
          icon: Icons.close,
          tooltip: l10n.windowClose,
          hover: Colors.red.withAlpha(38),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
