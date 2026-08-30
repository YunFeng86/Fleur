import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import 'shell_frame_geometry.dart';

/// Paints the shared content boundary for the connected desktop frame.
///
/// The title bar and navigation remain one surface. The content edge is
/// outlined once, with a rounded corner joining its horizontal and vertical
/// segments.
class ShellFrameBoundary extends StatelessWidget {
  const ShellFrameBoundary({super.key, required this.geometry});

  final ShellFrameGeometry geometry;

  @override
  Widget build(BuildContext context) {
    if (geometry.contentBoundaryRadius <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        key: const Key('shell_frame_boundary'),
        painter: _ShellFrameBoundaryPainter(
          left: geometry.dividerLeadingInset,
          top: geometry.titleBarHeight,
          radius: geometry.contentBoundaryRadius,
          color: Theme.of(context).fleurSurface.subtleDivider,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ShellFrameBoundaryPainter extends CustomPainter {
  const _ShellFrameBoundaryPainter({
    required this.left,
    required this.top,
    required this.radius,
    required this.color,
  });

  final double left;
  final double top;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || top <= 0) return;

    const strokeWidth = 1.0;
    final horizontalY = top - strokeWidth / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    final path = Path();

    if (left <= 0) {
      path
        ..moveTo(0, horizontalY)
        ..lineTo(size.width, horizontalY);
      canvas.drawPath(path, paint);
      return;
    }

    final boundedRadius = math.min(radius, math.min(left, size.height - top));
    final verticalX = left - strokeWidth / 2;
    final cornerTopX = left + boundedRadius;

    path
      ..moveTo(cornerTopX, horizontalY)
      ..lineTo(size.width, horizontalY)
      ..moveTo(cornerTopX, horizontalY)
      ..quadraticBezierTo(
        verticalX,
        horizontalY,
        verticalX,
        top + boundedRadius,
      )
      ..lineTo(verticalX, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShellFrameBoundaryPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}
