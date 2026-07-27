import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/fleur_icons.dart';
import '../../../theme/fleur_theme_extensions.dart';

const double kFleurSelectFieldHeight = 36;
const double kFleurSelectItemHeight = 36;
const double kFleurSelectMenuMaxHeight = 360;
const double _kFleurSelectRadius = 10;
const double _kFleurSelectMenuGap = 4;

class FleurSelectOption<T> {
  const FleurSelectOption({
    required this.value,
    required this.label,
    this.searchText,
    this.key,
  });

  final T value;
  final Widget label;
  final String? searchText;
  final Key? key;
}

class FleurSelectField<T> extends StatefulWidget {
  const FleurSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.leadingIcon,
    this.enableSearch = false,
    this.searchHint,
    this.menuMaxHeight = kFleurSelectMenuMaxHeight,
    this.fieldHeight = kFleurSelectFieldHeight,
    this.itemHeight = kFleurSelectItemHeight,
    this.showCheck = true,
  });

  final T value;
  final List<FleurSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final Widget? hint;
  final IconData? leadingIcon;
  final bool enableSearch;
  final String? searchHint;
  final double menuMaxHeight;
  final double fieldHeight;
  final double itemHeight;
  final bool showCheck;

  @override
  State<FleurSelectField<T>> createState() => _FleurSelectFieldState<T>();
}

class _FleurSelectFieldState<T> extends State<FleurSelectField<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _hovered = false;
  bool _focused = false;

  FleurSelectOption<T>? get _selectedOption {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FleurSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null || widget.options.isEmpty) {
      _removeMenu();
    }
  }

  void _removeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _select(T value) {
    _removeMenu();
    if (!mounted) return;
    widget.onChanged?.call(value);
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _removeMenu();
      return;
    }
    _openMenu();
  }

  void _openMenu() {
    if (widget.onChanged == null || widget.options.isEmpty) return;
    final renderObject = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox || overlay is! RenderBox) return;

    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final bottom = topLeft.dy + renderObject.size.height;
    final spaceBelow = overlay.size.height - bottom;
    final spaceAbove = topLeft.dy;
    final estimatedHeight = math.min(
      widget.menuMaxHeight,
      widget.options.length * widget.itemHeight +
          (widget.enableSearch ? 49 : 8),
    );
    final openAbove = spaceBelow < estimatedHeight && spaceAbove > spaceBelow;
    final availableHeight = math.max(
      96.0,
      (openAbove ? spaceAbove : spaceBelow) - 12,
    );
    final maxHeight = math.min(widget.menuMaxHeight, availableHeight);
    final width = renderObject.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: openAbove
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: openAbove
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset: Offset(
                0,
                openAbove ? -_kFleurSelectMenuGap : _kFleurSelectMenuGap,
              ),
              child: SizedBox(
                width: width,
                child: _FleurSelectMenu<T>(
                  value: widget.value,
                  options: widget.options,
                  enableSearch: widget.enableSearch,
                  searchHint: widget.searchHint,
                  maxHeight: maxHeight,
                  itemHeight: widget.itemHeight,
                  showCheck: widget.showCheck,
                  onSelected: _select,
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final enabled = widget.onChanged != null;
    final borderColor = !enabled
        ? surfaces.subtleDivider.withValues(alpha: 0.42)
        : _focused
        ? scheme.primary
        : _hovered
        ? scheme.outline
        : surfaces.subtleDivider;
    final foregroundColor = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final selectedOption = _selectedOption;

    return CompositedTransformTarget(
      link: _layerLink,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: widget.fieldHeight,
          decoration: BoxDecoration(
            color: surfaces.card,
            borderRadius: BorderRadius.circular(_kFleurSelectRadius),
            border: Border.all(color: borderColor, width: _focused ? 2 : 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(_kFleurSelectRadius),
              onTap: enabled ? _toggleMenu : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
                child: Row(
                  children: [
                    if (widget.leadingIcon case final leadingIcon?) ...[
                      Icon(
                        leadingIcon,
                        size: 16,
                        color: enabled
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface.withValues(alpha: 0.38),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child:
                            selectedOption?.label ??
                            widget.hint ??
                            const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      FleurIcons.dropdown,
                      size: 16,
                      color: enabled
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FleurSelectMenu<T> extends StatefulWidget {
  const _FleurSelectMenu({
    required this.value,
    required this.options,
    required this.enableSearch,
    required this.searchHint,
    required this.maxHeight,
    required this.itemHeight,
    required this.showCheck,
    required this.onSelected,
  });

  final T value;
  final List<FleurSelectOption<T>> options;
  final bool enableSearch;
  final String? searchHint;
  final double maxHeight;
  final double itemHeight;
  final bool showCheck;
  final ValueChanged<T> onSelected;

  @override
  State<_FleurSelectMenu<T>> createState() => _FleurSelectMenuState<T>();
}

class _FleurSelectMenuState<T> extends State<_FleurSelectMenu<T>> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    if (widget.enableSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<FleurSelectOption<T>> get _filteredOptions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if ((option.searchText ?? '').toLowerCase().contains(query)) option,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final scheme = theme.colorScheme;
    final filteredOptions = _filteredOptions;
    final searchHeight = widget.enableSearch ? 49.0 : 0.0;
    final maxListHeight = math.max(0.0, widget.maxHeight - searchHeight);
    final listContentHeight = filteredOptions.length * widget.itemHeight + 8;
    final listHeight = filteredOptions.isEmpty
        ? math.min(44.0, maxListHeight)
        : math.min(listContentHeight, maxListHeight);

    return Material(
      color: surfaces.floating,
      elevation: 8,
      shadowColor: theme.shadowColor.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kFleurSelectRadius),
        side: BorderSide(color: surfaces.subtleDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.enableSearch) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(FleurIcons.search, size: 15),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              Divider(height: 1, color: surfaces.subtleDivider),
            ],
            SizedBox(
              height: listHeight,
              child: filteredOptions.isEmpty
                  ? const SizedBox.shrink()
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: listContentHeight > maxListHeight,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemExtent: widget.itemHeight,
                        itemCount: filteredOptions.length,
                        itemBuilder: (context, index) {
                          final option = filteredOptions[index];
                          final selected = option.value == widget.value;
                          final foreground = selected
                              ? scheme.onSurface
                              : scheme.onSurface;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Material(
                              color: selected
                                  ? states.selectionTint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                key: option.key,
                                borderRadius: BorderRadius.circular(8),
                                hoverColor: states.hoverTint,
                                splashColor: states.pressedTint,
                                onTap: () => widget.onSelected(option.value),
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 10,
                                    end: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      if (widget.showCheck) ...[
                                        SizedBox(
                                          width: 18,
                                          child: selected
                                              ? Icon(
                                                  FleurIcons.check,
                                                  size: 15,
                                                  color: scheme.primary,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: DefaultTextStyle.merge(
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: foreground,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          child: option.label,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
