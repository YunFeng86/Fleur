import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class ShellTemporarySceneGate extends StatelessWidget {
  const ShellTemporarySceneGate({
    super.key,
    required this.navigationOpen,
    required this.child,
  });

  final bool navigationOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: navigationOpen,
      child: ExcludeSemantics(excluding: navigationOpen, child: child),
    );
  }
}

class ShellNavigationDismissScrim extends StatelessWidget {
  const ShellNavigationDismissScrim({
    super.key,
    required this.onDismiss,
    required this.color,
  });

  final VoidCallback onDismiss;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('shell_navigation_dismiss_scrim'),
      container: true,
      button: true,
      label: AppLocalizations.of(context)!.close,
      onTap: onDismiss,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onDismiss,
        child: ColoredBox(color: color),
      ),
    );
  }
}
