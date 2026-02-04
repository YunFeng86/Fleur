import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/platform.dart';

class DesktopTitleBar extends StatefulWidget {
  const DesktopTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.height = 40,
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

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Material(
      color: cs.surface,
      child: SizedBox(
        height: widget.height,
        child: Row(
          children: [
            if (isMacOS) const SizedBox(width: 72), // avoid traffic lights
            if (widget.leading != null) widget.leading!,
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ),
              ),
            ),
            ...widget.actions,
            if (!isMacOS) _WindowButtons(isMaximized: _isMaximized),
          ],
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
          tooltip: 'Minimize',
          onPressed: () => windowManager.minimize(),
        ),
        btn(
          icon: isMaximized ? Icons.filter_none : Icons.crop_square,
          tooltip: isMaximized ? 'Restore' : 'Maximize',
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
          tooltip: 'Close',
          hover: Colors.red.withAlpha(38),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}
