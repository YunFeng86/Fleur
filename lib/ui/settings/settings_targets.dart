import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';

class SettingsTargetController extends ChangeNotifier {
  String? _highlightedId;
  final Map<String, GlobalKey> _keys = {};

  String? get highlightedId => _highlightedId;

  GlobalKey keyFor(String id) {
    return _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
  }

  BuildContext? contextFor(String id) {
    return _keys[id]?.currentContext;
  }

  void highlight(String id) {
    _highlightedId = id;
    notifyListeners();
  }

  void clear(String id) {
    if (_highlightedId != id) return;
    _highlightedId = null;
    notifyListeners();
  }
}

class SettingsTargetAnchor extends StatefulWidget {
  const SettingsTargetAnchor({
    super.key,
    required this.id,
    required this.controller,
    required this.child,
  });

  final String id;
  final SettingsTargetController controller;
  final Widget child;

  @override
  State<SettingsTargetAnchor> createState() => _SettingsTargetAnchorState();
}

class _SettingsTargetAnchorState extends State<SettingsTargetAnchor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleHighlightChanged);
  }

  @override
  void didUpdateWidget(covariant SettingsTargetAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleHighlightChanged);
    widget.controller.addListener(_handleHighlightChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleHighlightChanged);
    super.dispose();
  }

  void _handleHighlightChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.controller.highlightedId == widget.id;
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: Key('settings_target_${widget.id}'),
      child: AnimatedContainer(
        key: widget.controller.keyFor(widget.id),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: highlighted ? theme.fleurState.selectionTint : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: widget.child,
      ),
    );
  }
}
