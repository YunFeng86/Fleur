import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';
import '../../design_system/design_system.dart';

const double _kSettingsControlBreakpoint = 680;
const double _kSettingsControlMinWidth = 220;
const double _kSettingsControlMaxWidth = 320;
const double _kSettingsControlGap = 16;
const double _kSettingsControlRowMinHeight = 52;
const double _kSettingsControlRowWithSubtitleMinHeight = 64;
const Size _kSettingsSwitchHitSize = Size(48, 40);
const double _kSettingsSwitchVisualWidth = 42;
const double _kSettingsSwitchVisualHeight = 28;
const double _kSettingsSwitchTrackHeight = 14;
const double _kSettingsSwitchThumbSize = 24;
const double _kSettingsSwitchHaloSize = 44;

class SettingsTileGroup extends StatelessWidget {
  const SettingsTileGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final items = <Widget>[];

    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        items.add(Divider(color: surfaces.subtleDivider, height: 1));
      }
      items.add(children[index]);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onSecondaryTapDown,
    this.destructive = false,
    this.selected = false,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool destructive;
  final bool selected;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    final scheme = theme.colorScheme;
    final titleColor = destructive ? states.errorAccent : null;
    final minHeight = subtitle == null
        ? _kSettingsControlRowMinHeight
        : _kSettingsControlRowWithSubtitleMinHeight;
    final titleStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(color: titleColor);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: contentPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(style: titleStyle, child: title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: subtitleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );

    return IconTheme.merge(
      data: IconThemeData(color: destructive ? states.errorAccent : null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: onSecondaryTapDown,
        child: FleurSelectableButton(
          selected: selected,
          onPressed: onTap,
          minimumHeight: minHeight,
          alignment: AlignmentDirectional.centerStart,
          borderRadius: BorderRadius.zero,
          selectedBackgroundColor: states.selectionTint,
          selectedForegroundColor: destructive
              ? states.errorAccent
              : scheme.onSurface,
          unselectedForegroundColor: destructive
              ? states.errorAccent
              : scheme.onSurface,
          child: row,
        ),
      ),
    );
  }
}

class SettingsControlRow extends StatelessWidget {
  const SettingsControlRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.controlWidth,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget control;
  final EdgeInsetsGeometry padding;
  final double? controlWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boundedWidth = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final wide =
            maxWidth.isFinite && maxWidth >= _kSettingsControlBreakpoint;
        final titleBlock = _SettingsControlTitle(
          title: title,
          subtitle: subtitle,
          leading: leading,
        );
        final minHeight = subtitle == null
            ? _kSettingsControlRowMinHeight
            : _kSettingsControlRowWithSubtitleMinHeight;

        if (!wide) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titleBlock, const SizedBox(height: 12), control],
            ),
          );
        }

        final resolvedControlWidth =
            controlWidth ??
            (maxWidth * 0.42)
                .clamp(_kSettingsControlMinWidth, _kSettingsControlMaxWidth)
                .toDouble();

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: _kSettingsControlGap),
                SizedBox(width: resolvedControlWidth, child: control),
              ],
            ),
          ),
        );
      },
    );

    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      child: boundedWidth,
    );
  }
}

class _SettingsControlTitle extends StatelessWidget {
  const _SettingsControlTitle({
    required this.title,
    required this.subtitle,
    required this.leading,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                child: title,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: subtitleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: subtitle!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsLeadingAvatar extends StatelessWidget {
  const SettingsLeadingAvatar({super.key, required this.child, this.size = 22});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: surfaces.card, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.secondary,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? secondary;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500) ??
        const TextStyle(fontWeight: FontWeight.w500);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final minHeight = subtitle == null
        ? _kSettingsControlRowMinHeight
        : _kSettingsControlRowWithSubtitleMinHeight;
    final enabled = onChanged != null;
    final semanticLabel = _plainTextLabel(title);

    return IconTheme.merge(
      data: IconThemeData(color: theme.colorScheme.onSurfaceVariant),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (secondary != null) ...[secondary!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(style: titleStyle, child: title),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: subtitleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Semantics(
                label: semanticLabel,
                toggled: value,
                enabled: enabled,
                onTap: enabled ? () => onChanged!(!value) : null,
                child: ExcludeSemantics(
                  child: SettingsCompactSwitch(
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsCompactSwitch extends StatefulWidget {
  const SettingsCompactSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<SettingsCompactSwitch> createState() => _SettingsCompactSwitchState();
}

class _SettingsCompactSwitchState extends State<SettingsCompactSwitch> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onChanged != null;

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final dark = theme.brightness == Brightness.dark;
    final selected = widget.value;
    final enabled = _enabled;
    final haloVisible = enabled && (_hovered || _pressed || _focused);

    final trackColor = enabled
        ? selected
              ? scheme.primary.withAlpha(dark ? 118 : 62)
              : scheme.onSurfaceVariant.withAlpha(dark ? 104 : 42)
        : scheme.onSurface.withAlpha(dark ? 34 : 22);
    final thumbColor = enabled
        ? selected
              ? scheme.primary
              : (dark ? scheme.surfaceContainerHighest : surfaces.floating)
        : scheme.onSurface.withAlpha(dark ? 86 : 64);
    final thumbBorderColor = enabled
        ? selected
              ? scheme.primary.withAlpha(160)
              : scheme.outlineVariant.withAlpha(dark ? 150 : 150)
        : Colors.transparent;
    final haloColor = haloVisible
        ? _focused
              ? states.focusRing.withAlpha(dark ? 76 : 42)
              : selected
              ? scheme.primary.withAlpha(dark ? 72 : 38)
              : scheme.onSurface.withAlpha(dark ? 48 : 34)
        : Colors.transparent;
    final haloBorderColor = _focused
        ? states.focusRing.withAlpha(dark ? 210 : 150)
        : Colors.transparent;
    final haloShadowColor = haloVisible
        ? selected
              ? scheme.primary.withAlpha(dark ? 50 : 22)
              : (dark
                    ? scheme.onSurface.withAlpha(30)
                    : Colors.black.withAlpha(24))
        : Colors.transparent;

    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowFocusHighlight: (focused) {
        if (_focused == focused) return;
        setState(() => _focused = focused);
      },
      onShowHoverHighlight: (hovered) {
        if (_hovered == hovered) return;
        setState(() => _hovered = hovered);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            _toggle();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: SizedBox.fromSize(
          size: _kSettingsSwitchHitSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              width: _kSettingsSwitchHitSize.width,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.transparent),
              child: SizedBox(
                width: _kSettingsSwitchVisualWidth,
                height: _kSettingsSwitchVisualHeight,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: _kSettingsSwitchVisualWidth,
                      height: _kSettingsSwitchTrackHeight,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(
                          _kSettingsSwitchTrackHeight / 2,
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      alignment: selected
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: _kSettingsSwitchThumbSize,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            width: haloVisible
                                ? (_pressed
                                      ? _kSettingsSwitchHaloSize - 2
                                      : _kSettingsSwitchHaloSize)
                                : _kSettingsSwitchThumbSize,
                            height: haloVisible
                                ? (_pressed
                                      ? _kSettingsSwitchHaloSize - 2
                                      : _kSettingsSwitchHaloSize)
                                : _kSettingsSwitchThumbSize,
                            decoration: BoxDecoration(
                              color: haloColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: haloBorderColor,
                                width: 1.2,
                              ),
                              boxShadow: haloVisible
                                  ? [
                                      BoxShadow(
                                        color: haloShadowColor,
                                        blurRadius: _pressed ? 8 : 12,
                                        spreadRadius: _pressed ? -1 : 0,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      alignment: selected
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        width: _kSettingsSwitchThumbSize,
                        height: _kSettingsSwitchThumbSize,
                        decoration: BoxDecoration(
                          color: thumbColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: thumbBorderColor),
                          boxShadow: enabled
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      dark ? 82 : 38,
                                    ),
                                    blurRadius: _pressed ? 4 : 7,
                                    offset: Offset(0, _pressed ? 1 : 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
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

String? _plainTextLabel(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText();
  }
  return null;
}
