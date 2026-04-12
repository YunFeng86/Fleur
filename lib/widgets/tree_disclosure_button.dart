import 'package:flutter/material.dart';

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
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        style: const ButtonStyle(shape: WidgetStatePropertyAll(CircleBorder())),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_right),
      ),
    );
  }
}
