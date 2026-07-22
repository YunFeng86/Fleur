import 'package:flutter/material.dart';

/// Preserves the first visible registered row while a list changes shape.
class ScrollAnchorRegistry {
  ScrollAnchorRegistry({required ScrollController Function() scrollController})
    : _scrollController = scrollController;

  final ScrollController Function() _scrollController;
  final Map<String, BuildContext> _rowContexts = <String, BuildContext>{};

  final GlobalKey viewportKey = GlobalKey(debugLabel: 'scroll-anchor-viewport');

  bool _disposed = false;

  void runWithAnchor(VoidCallback action) {
    if (_disposed) {
      action();
      return;
    }
    final anchor = _capture();
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _restore(anchor);
    });
  }

  void dispose() {
    _disposed = true;
    _rowContexts.clear();
  }

  void _register(String rowId, BuildContext context) {
    if (!_disposed) _rowContexts[rowId] = context;
  }

  void _unregister(String rowId, BuildContext context) {
    if (identical(_rowContexts[rowId], context)) {
      _rowContexts.remove(rowId);
    }
  }

  _ScrollAnchor? _capture() {
    final scrollController = _scrollController();
    if (!scrollController.hasClients) return null;
    final listBox = viewportKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return null;
    final viewportTop = listBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + listBox.size.height;

    _ScrollAnchor? bestFullyVisible;
    var bestFullyVisibleTop = double.infinity;
    _ScrollAnchor? bestPartial;
    var bestPartialDistance = double.infinity;
    for (final entry in _rowContexts.entries) {
      final rowBox = entry.value.findRenderObject();
      if (rowBox is! RenderBox || !rowBox.attached || !rowBox.hasSize) {
        continue;
      }
      final top = rowBox.localToGlobal(Offset.zero).dy;
      final bottom = top + rowBox.size.height;
      if (bottom < viewportTop || top > viewportBottom) continue;
      if (top >= viewportTop) {
        if (top < bestFullyVisibleTop) {
          bestFullyVisibleTop = top;
          bestFullyVisible = _ScrollAnchor(rowId: entry.key, top: top);
        }
      } else {
        final distance = (top - viewportTop).abs();
        if (distance < bestPartialDistance) {
          bestPartialDistance = distance;
          bestPartial = _ScrollAnchor(rowId: entry.key, top: top);
        }
      }
    }
    return bestFullyVisible ?? bestPartial;
  }

  void _restore(_ScrollAnchor? anchor) {
    if (anchor == null) return;
    final scrollController = _scrollController();
    if (!scrollController.hasClients) return;
    final rowBox = _rowContexts[anchor.rowId]?.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.attached || !rowBox.hasSize) return;
    final nextTop = rowBox.localToGlobal(Offset.zero).dy;
    final delta = nextTop - anchor.top;
    if (delta.abs() < 0.5) return;
    final position = scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    scrollController.jumpTo(next);
  }
}

class ScrollAnchorRegistryRow extends StatefulWidget {
  const ScrollAnchorRegistryRow({
    super.key,
    required this.registry,
    required this.rowId,
    required this.child,
  });

  final ScrollAnchorRegistry registry;
  final String rowId;
  final Widget child;

  @override
  State<ScrollAnchorRegistryRow> createState() =>
      _ScrollAnchorRegistryRowState();
}

class _ScrollAnchorRegistryRowState extends State<ScrollAnchorRegistryRow> {
  @override
  void initState() {
    super.initState();
    widget.registry._register(widget.rowId, context);
  }

  @override
  void didUpdateWidget(covariant ScrollAnchorRegistryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry ||
        oldWidget.rowId != widget.rowId) {
      oldWidget.registry._unregister(oldWidget.rowId, context);
      widget.registry._register(widget.rowId, context);
    }
  }

  @override
  void dispose() {
    widget.registry._unregister(widget.rowId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ScrollAnchor {
  const _ScrollAnchor({required this.rowId, required this.top});

  final String rowId;
  final double top;
}
