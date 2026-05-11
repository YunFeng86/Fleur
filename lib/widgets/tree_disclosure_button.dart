import 'package:flutter/material.dart';

import '../theme/fleur_icons.dart';

class TreeDisclosureButton extends StatelessWidget {
  const TreeDisclosureButton({
    super.key,
    required this.expanded,
    required this.tooltip,
    required this.onPressed,
  });

  final bool expanded;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onSurfaceVariant),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(CircleBorder()),
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(expanded ? FleurIcons.collapse : FleurIcons.expand),
      ),
    );
  }
}
