import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';
import '../../motion.dart';
import '../../../widgets/app_scrollbar.dart';
import '../../../widgets/fleur_select_field.dart';

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

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.bottomSpacing = 12,
  });

  final String title;
  final String? description;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description case final description?) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({
    super.key,
    required this.children,
    this.maxWidth = 800,
    this.padding = const EdgeInsets.all(24),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.scrollController,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return AppScrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        primary: scrollController == null,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.bottomSpacing = 24,
  });

  final String title;
  final String? description;
  final Widget child;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, description: description),
        child,
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
  }
}

class SettingsPane extends StatelessWidget {
  const SettingsPane({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.color,
    this.onHeaderSecondaryTapDown,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final GestureTapDownCallback? onHeaderSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final hasHeader = title != null || subtitle != null || trailing != null;

    return Card(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: onHeaderSecondaryTapDown,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title case final title?)
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (subtitle case final subtitle?) ...[
                            if (title != null) const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          if (hasHeader) Divider(color: surfaces.subtleDivider, height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

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
        child: Material(
          color: selected ? states.selectionTint : Colors.transparent,
          animationDuration: AppMotion.effectiveDuration(
            context,
            AppMotion.selectionTransitionDuration,
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: states.hoverTint,
            splashColor: states.pressedTint,
            child: row,
          ),
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

typedef SettingsSelectOption<T> = FleurSelectOption<T>;

class SettingsSelectField<T> extends FleurSelectField<T> {
  const SettingsSelectField({
    super.key,
    required super.value,
    required super.options,
    required super.onChanged,
    super.hint,
  });
}

class SettingsSliderControl extends StatelessWidget {
  const SettingsSliderControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    this.minLabel,
    this.maxLabel,
    this.valueLabel,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String Function(double value) format;
  final String? minLabel;
  final String? maxLabel;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2.5,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (valueLabel != null) ...[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(valueLabel!, style: labelStyle),
          ),
          const SizedBox(height: 2),
        ],
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: sliderTheme,
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Text(minLabel ?? format(min), style: labelStyle),
              const Spacer(),
              Text(maxLabel ?? format(max), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

enum SettingsActionButtonVariant { outline, filled, text }

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = SettingsActionButtonVariant.outline,
  });

  final VoidCallback? onPressed;
  final Widget label;
  final Widget? icon;
  final SettingsActionButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final surfaces = theme.fleurSurface;
    final enabled = onPressed != null;
    final foreground = switch (variant) {
      SettingsActionButtonVariant.filled => scheme.onPrimary,
      SettingsActionButtonVariant.outline ||
      SettingsActionButtonVariant.text => scheme.primary,
    };
    final background = switch (variant) {
      SettingsActionButtonVariant.filled => scheme.primary,
      SettingsActionButtonVariant.outline ||
      SettingsActionButtonVariant.text => Colors.transparent,
    };
    final border = variant == SettingsActionButtonVariant.outline
        ? Border.all(color: surfaces.subtleDivider)
        : null;
    final content = IconTheme.merge(
      data: IconThemeData(
        size: 16,
        color: enabled ? foreground : scheme.onSurface.withValues(alpha: 0.38),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelMedium?.copyWith(
          color: enabled
              ? foreground
              : scheme.onSurface.withValues(alpha: 0.38),
          fontWeight: FontWeight.w600,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Flexible(child: label),
          ],
        ),
      ),
    );

    return Material(
      color: enabled ? background : surfaces.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: border?.top ?? BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        hoverColor: states.hoverTint,
        splashColor: states.pressedTint,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

class SettingsIconActionButton extends StatelessWidget {
  const SettingsIconActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(32)),
        minimumSize: const WidgetStatePropertyAll(Size.square(32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        overlayColor: WidgetStateProperty.resolveWith((stateSet) {
          if (stateSet.contains(WidgetState.pressed)) return states.pressedTint;
          if (stateSet.contains(WidgetState.hovered) ||
              stateSet.contains(WidgetState.focused)) {
            return states.hoverTint;
          }
          return null;
        }),
      ),
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

class SettingsDetailHeader extends StatelessWidget {
  const SettingsDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.subtitleWidget,
    this.bottomSpacing = 24,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 6),
                  subtitleWidget!,
                ] else if (subtitle case final subtitle?) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}
