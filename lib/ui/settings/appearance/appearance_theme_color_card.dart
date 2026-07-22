import 'package:flutter/material.dart';

import '../../../theme/fleur_icons.dart';
import '../../design_system/design_system.dart';

class AppearanceThemeColorCard extends StatelessWidget {
  const AppearanceThemeColorCard({
    super.key,
    required this.selected,
    required this.scheme,
    required this.onTap,
    this.semanticLabel,
  });

  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const tapSize = 72.0;
    const swatchSize = 54.0;
    final selectedColor = Theme.of(context).colorScheme.primary;
    final onSelectedColor = Theme.of(context).colorScheme.onPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: SizedBox(
        width: tapSize,
        height: tapSize,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            radius: tapSize / 2,
            child: FleurSelectionTransition(
              selected: selected,
              builder: (context, selection, _) {
                return Stack(
                  children: [
                    Center(
                      child: CustomPaint(
                        size: const Size.square(swatchSize),
                        painter: _AppearanceSchemeSwatchPainter(
                          scheme,
                          outlineColor: Color.lerp(
                            scheme.outline,
                            selectedColor,
                            selection,
                          )!,
                          outlineWidth: 2 + (selection * 2),
                        ),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: selection,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FleurIcons.check,
                            size: 18,
                            color: onSelectedColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceSchemeSwatchPainter extends CustomPainter {
  const _AppearanceSchemeSwatchPainter(
    this.scheme, {
    required this.outlineColor,
    required this.outlineWidth,
  });

  final ColorScheme scheme;
  final Color outlineColor;
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    final clip = Path()..addOval(rect);
    canvas.save();
    canvas.clipPath(clip);

    paint.color = scheme.primary;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), paint);

    paint.color = scheme.secondary;
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height / 2),
      paint,
    );

    paint.color = scheme.tertiary;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2,
        size.width / 2,
        size.height / 2,
      ),
      paint,
    );

    canvas.restore();

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth
      ..color = outlineColor;
    canvas.drawOval(rect.deflate(1), stroke);
  }

  @override
  bool shouldRepaint(covariant _AppearanceSchemeSwatchPainter oldDelegate) {
    return oldDelegate.scheme != scheme ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.outlineWidth != outlineWidth;
  }
}
