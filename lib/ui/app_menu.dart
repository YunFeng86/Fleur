import 'dart:async';

import 'package:flutter/material.dart';

class AppMenuItem<T> {
  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.leadingBuilder,
    this.enabled = true,
    this.destructive = false,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final WidgetBuilder? leadingBuilder;
  final bool enabled;
  final bool destructive;
  final Key? key;
}

class AppMenuHost extends StatefulWidget {
  const AppMenuHost({super.key, required this.child});

  final Widget child;

  static Future<T?> showAt<T>(
    BuildContext context, {
    required Offset position,
    required List<AppMenuItem<T>> items,
  }) {
    if (items.isEmpty) return Future<T?>.value();
    final state = context.findAncestorStateOfType<_AppMenuHostState>();
    assert(
      state != null,
      'AppMenuHost.showAt requires an AppMenuHost ancestor.',
    );
    return state?._showAt<T>(position: position, items: items) ??
        Future<T?>.value();
  }

  @override
  State<AppMenuHost> createState() => _AppMenuHostState();
}

class _AppMenuHostState extends State<AppMenuHost> {
  final MenuController _controller = MenuController();
  final GlobalKey _anchorKey = GlobalKey();
  List<AppMenuItem<dynamic>> _items = const [];
  Completer<Object?>? _completion;
  int _openRequestId = 0;

  Future<T?> _showAt<T>({
    required Offset position,
    required List<AppMenuItem<T>> items,
  }) {
    _complete(null, closeMenu: true);

    final completion = Completer<Object?>();
    final requestId = ++_openRequestId;
    setState(() {
      _completion = completion;
      _items = items;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openRequestId != requestId) return;
      final anchorBox = _anchorKey.currentContext?.findRenderObject();
      if (anchorBox is! RenderBox || !anchorBox.hasSize) {
        _complete(null, closeMenu: false);
        return;
      }
      _controller.open(position: anchorBox.globalToLocal(position));
    });

    return completion.future.then((value) => value as T?);
  }

  void _select(Object? value) {
    _complete(value, closeMenu: true);
  }

  void _complete(Object? value, {required bool closeMenu}) {
    final completion = _completion;
    _completion = null;
    _openRequestId++;
    if (completion != null && !completion.isCompleted) {
      completion.complete(value);
    }
    if (closeMenu && _controller.isOpen) {
      _controller.close();
    }
    if (mounted && _items.isNotEmpty) {
      setState(() => _items = const []);
    }
  }

  void _handleClose() {
    if (_completion == null) return;
    final requestId = _openRequestId;
    scheduleMicrotask(() {
      if (!mounted || _completion == null || _openRequestId != requestId) {
        return;
      }
      _complete(null, closeMenu: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          left: 0,
          top: 0,
          child: MenuAnchor(
            controller: _controller,
            consumeOutsideTap: false,
            onClose: _handleClose,
            menuChildren: AppMenuTiles.menuButtons<dynamic>(
              context: context,
              items: _items,
              onSelected: _select,
            ),
            builder: (context, controller, child) {
              return KeyedSubtree(
                key: _anchorKey,
                child: child ?? const SizedBox.shrink(),
              );
            },
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class AppMenuButton<T> extends StatefulWidget {
  const AppMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    required this.icon,
    required this.tooltip,
    this.buttonKey,
    this.iconSize,
    this.constraints,
    this.padding,
    this.style,
    this.onOpenChanged,
  });

  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final IconData icon;
  final String tooltip;
  final Key? buttonKey;
  final double? iconSize;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final ButtonStyle? style;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<AppMenuButton<T>> createState() => _AppMenuButtonState<T>();
}

class _AppMenuButtonState<T> extends State<AppMenuButton<T>> {
  final MenuController _controller = MenuController();

  void _select(T value) {
    _controller.close();
    widget.onSelected(value);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      consumeOutsideTap: false,
      onOpen: () => widget.onOpenChanged?.call(true),
      onClose: () => widget.onOpenChanged?.call(false),
      menuChildren: AppMenuTiles.menuButtons<T>(
        context: context,
        items: widget.items,
        onSelected: _select,
      ),
      builder: (context, controller, child) {
        return IconButton(
          key: widget.buttonKey,
          tooltip: widget.tooltip,
          iconSize: widget.iconSize,
          constraints: widget.constraints,
          padding: widget.padding,
          style: widget.style,
          onPressed: widget.items.isEmpty
              ? null
              : () {
                  controller.isOpen ? controller.close() : controller.open();
                },
          icon: Icon(widget.icon),
        );
      },
    );
  }
}

class AppMenuTiles {
  const AppMenuTiles._();

  static List<Widget> menuButtons<T>({
    required BuildContext context,
    required List<AppMenuItem<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return [
      for (final item in items)
        MenuItemButton(
          key: item.key,
          closeOnActivate: false,
          leadingIcon: _leadingIcon(
            context: context,
            item: item,
            errorColor: errorColor,
          ),
          onPressed: item.enabled ? () => onSelected(item.value) : null,
          child: Text(
            item.label,
            style: item.destructive ? TextStyle(color: errorColor) : null,
          ),
        ),
    ];
  }

  static List<Widget> bottomSheetTiles<T>({
    required BuildContext context,
    required List<AppMenuItem<T>> items,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return [
      for (final item in items)
        ListTile(
          key: item.key,
          enabled: item.enabled,
          leading: _leadingIcon(
            context: context,
            item: item,
            errorColor: errorColor,
          ),
          title: Text(
            item.label,
            style: item.destructive ? TextStyle(color: errorColor) : null,
          ),
          onTap: item.enabled
              ? () => Navigator.of(context).pop(item.value)
              : null,
        ),
    ];
  }

  static Widget? _leadingIcon<T>({
    required BuildContext context,
    required AppMenuItem<T> item,
    required Color errorColor,
  }) {
    final leadingBuilder = item.leadingBuilder;
    if (leadingBuilder != null) return leadingBuilder(context);
    final icon = item.icon;
    if (icon == null) return null;
    return Icon(icon, color: item.destructive ? errorColor : null);
  }
}
