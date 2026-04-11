import 'package:flutter/material.dart';

import 'dart:async' show unawaited;

import '../ui/motion.dart';

/// A tiny, dependency-free marquee that only animates when the text overflows.
///
/// This is intentionally simple: it "ping-pongs" left/right so users can read
/// the hidden part without needing an always-scrolling ticker.
class OverflowMarquee extends StatefulWidget {
  const OverflowMarquee({
    super.key,
    required this.text,
    this.style,
    this.pixelsPerSecond = 24,
    this.pause = const Duration(milliseconds: 600),
  });

  final String text;
  final TextStyle? style;
  final double pixelsPerSecond;
  final Duration pause;

  @override
  State<OverflowMarquee> createState() => _OverflowMarqueeState();
}

class _OverflowMarqueeState extends State<OverflowMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;
  String _lastText = '';
  double _lastWidth = -1;
  TextStyle? _lastStyle;
  TextDirection? _lastDirection;

  void _invalidateMeasurementCache() {
    _lastText = '';
    _lastWidth = -1;
    _lastStyle = null;
    _lastDirection = null;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stop() {
    if (_controller.isAnimating) _controller.stop();
    _controller.value = 0;
  }

  Future<void> _start() async {
    if (!mounted) return;
    if (_overflow <= 0) {
      _stop();
      return;
    }

    final ms = (_overflow / widget.pixelsPerSecond * 1000).round().clamp(
      900,
      12000,
    );
    _controller.duration = Duration(milliseconds: ms);

    // Restart with a short pause so it doesn't feel jittery.
    _stop();
    await Future<void>.delayed(widget.pause);
    if (!mounted || _overflow <= 0) return;
    unawaited(_controller.repeat(reverse: true));
  }

  void _measureAndMaybeAnimate(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final style = widget.style;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    final unchanged =
        _lastText == widget.text &&
        _lastWidth == width &&
        _lastStyle == style &&
        _lastDirection == direction;
    if (unchanged) return;

    _lastText = widget.text;
    _lastWidth = width;
    _lastStyle = style;
    _lastDirection = direction;

    if (width <= 0) {
      _overflow = 0;
      _stop();
      return;
    }

    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    _overflow = (tp.width - width).clamp(0, double.infinity);
    if (_overflow <= 0) {
      _stop();
      return;
    }

    // Fire-and-forget. We don't await here because we're in layout.
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      _stop();
      // Reduced-motion can toggle at runtime. Clear the cached measurement so
      // we re-measure and restart the marquee if motion is later re-enabled.
      _invalidateMeasurementCache();
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _measureAndMaybeAnimate(constraints);

        if (_overflow <= 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = -_overflow * _controller.value;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        );
      },
    );
  }
}
