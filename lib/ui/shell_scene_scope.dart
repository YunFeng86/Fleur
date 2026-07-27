import 'package:flutter/widgets.dart';

enum ShellSceneKind { workspace, settings }

class ShellSceneScope extends InheritedWidget {
  const ShellSceneScope({
    super.key,
    required this.activeScene,
    required super.child,
  });

  final ShellSceneKind activeScene;

  static ShellSceneKind of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellSceneScope>();
    assert(scope != null, 'ShellSceneScope is missing above a shell route.');
    return scope!.activeScene;
  }

  @override
  bool updateShouldNotify(ShellSceneScope oldWidget) {
    return activeScene != oldWidget.activeScene;
  }
}

class ShellSceneGate extends StatelessWidget {
  const ShellSceneGate({super.key, required this.scene, required this.child});

  final ShellSceneKind scene;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ShellSceneScope.of(context) != scene) {
      return const SizedBox.shrink();
    }
    return child;
  }
}
