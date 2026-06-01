import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';
import '../layout.dart';

Future<T?> showSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  double widthFraction = 0.4,
  double minWidth = 360,
  double maxWidth = 520,
}) {
  final size = MediaQuery.sizeOf(context);
  final totalWidth = size.width;
  final totalHeight = size.height;
  final isCompact = totalWidth < kCompactWidth;
  final panelWidth = isCompact
      ? totalWidth
      : (totalWidth * widthFraction).clamp(minWidth, maxWidth).toDouble();

  final theme = Theme.of(context);
  final borderRadius = isCompact
      ? BorderRadius.zero
      : const BorderRadius.horizontal(left: Radius.circular(16));

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: theme.fleurSurface.floating,
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: panelWidth,
            height: totalHeight,
            child: builder(context),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
