import 'package:flutter/widgets.dart';

RelativeRect contextMenuPositionForGlobalPoint(
  BuildContext context,
  Offset globalPosition,
) {
  final overlay = Overlay.maybeOf(context);
  final overlayBox = overlay?.context.findRenderObject();
  if (overlayBox is RenderBox && overlayBox.hasSize) {
    final localPoint = overlayBox.globalToLocal(globalPosition);
    return RelativeRect.fromRect(
      localPoint & Size.zero,
      Offset.zero & overlayBox.size,
    );
  }

  return RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, 0, 0);
}
