import 'package:flutter/material.dart';

class AppDrawerScope extends InheritedWidget {
  const AppDrawerScope({
    super.key,
    required this.hasAppDrawer,
    this.openDrawer,
    required super.child,
  });

  final bool hasAppDrawer;
  final VoidCallback? openDrawer;

  bool get canOpenDrawer => openDrawer != null;

  static AppDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDrawerScope>();
  }

  static VoidCallback? drawerOpenerOf(BuildContext context) {
    return maybeOf(context)?.openDrawer;
  }

  static Widget? drawerLeading(BuildContext context) {
    final openDrawer = drawerOpenerOf(context);
    if (openDrawer == null) return null;
    return IconButton(
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: openDrawer,
      icon: const Icon(Icons.menu),
    );
  }

  @override
  bool updateShouldNotify(AppDrawerScope oldWidget) =>
      oldWidget.hasAppDrawer != hasAppDrawer ||
      oldWidget.openDrawer != openDrawer;
}
