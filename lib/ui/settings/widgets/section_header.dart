import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';
import '../../../widgets/app_scrollbar.dart';

export 'settings_action_buttons.dart'
    show
        SettingsActionButton,
        SettingsActionButtonVariant,
        SettingsIconActionButton;
export 'settings_input_controls.dart'
    show SettingsSelectField, SettingsSelectOption, SettingsSliderControl;
export 'settings_tiles.dart'
    show
        SettingsCompactSwitch,
        SettingsControlRow,
        SettingsLeadingAvatar,
        SettingsSwitchTile,
        SettingsTile,
        SettingsTileGroup;

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
