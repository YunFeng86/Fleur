import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import '../ui/layout.dart';

enum FleurEmptyStateVariant { reader, list }

class FleurEmptyState extends StatelessWidget {
  const FleurEmptyState({
    super.key,
    required this.variant,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final FleurEmptyStateVariant variant;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final isReader = variant == FleurEmptyStateVariant.reader;
    final dark = theme.brightness == Brightness.dark;
    final background = isReader ? surfaces.reader : surfaces.list;
    final textColor = scheme.onSurface;
    final mutedTextColor = scheme.onSurfaceVariant;
    final iconColor = isReader
        ? mutedTextColor.withAlpha(dark ? 90 : 76)
        : scheme.primary;
    final titleStyle =
        (isReader ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(color: textColor, fontWeight: FontWeight.w700);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: mutedTextColor,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReader)
          Icon(icon, size: 44, color: iconColor)
        else
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: surfaces.floating,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: iconColor),
          ),
        const SizedBox(height: 16),
        Text(title, style: titleStyle, textAlign: TextAlign.center),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: subtitleStyle, textAlign: TextAlign.center),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: actions,
          ),
        ],
      ],
    );

    return Container(
      color: background,
      alignment: Alignment.center,
      padding: EdgeInsets.all(isReader ? 32 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isReader ? kMaxReadingWidth : 420,
        ),
        child: content,
      ),
    );
  }
}
