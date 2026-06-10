import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ShellTitleBarState {
  const ShellTitleBarState({
    this.title = '',
    this.trailingBuilder,
    this.trailingWidth = 0,
    this.owner,
  });

  final String title;
  final WidgetBuilder? trailingBuilder;
  final double trailingWidth;
  final Object? owner;

  bool get hasTrailing => trailingBuilder != null && trailingWidth > 0;
}

class ShellTitleBarController extends Notifier<ShellTitleBarState> {
  @override
  ShellTitleBarState build() => const ShellTitleBarState();

  void setTitleBar(ShellTitleBarState value) {
    state = value;
  }

  void clear(Object owner) {
    if (state.owner != owner) return;
    state = const ShellTitleBarState();
  }
}

final shellTitleBarControllerProvider =
    NotifierProvider<ShellTitleBarController, ShellTitleBarState>(
      ShellTitleBarController.new,
    );

class ShellTitleBarRegistration extends ConsumerStatefulWidget {
  const ShellTitleBarRegistration({
    super.key,
    required this.title,
    required this.trailingBuilder,
    required this.trailingWidth,
    required this.child,
  });

  final String title;
  final WidgetBuilder trailingBuilder;
  final double trailingWidth;
  final Widget child;

  @override
  ConsumerState<ShellTitleBarRegistration> createState() =>
      _ShellTitleBarRegistrationState();
}

class _ShellTitleBarRegistrationState
    extends ConsumerState<ShellTitleBarRegistration> {
  final Object _owner = Object();
  late final ShellTitleBarController _controller;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(shellTitleBarControllerProvider.notifier);
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(covariant ShellTitleBarRegistration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.trailingBuilder != widget.trailingBuilder ||
        oldWidget.trailingWidth != widget.trailingWidth) {
      _scheduleUpdate();
    }
  }

  @override
  void dispose() {
    _controller.clear(_owner);
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      _controller.setTitleBar(
        ShellTitleBarState(
          title: widget.title,
          trailingBuilder: widget.trailingBuilder,
          trailingWidth: widget.trailingWidth,
          owner: _owner,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
