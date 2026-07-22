import 'package:flutter/material.dart';

import '../../app/settings_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/fleur_icons.dart';
import '../../theme/fleur_theme_extensions.dart';
import 'settings_search_index.dart';
import 'widgets/settings_controls.dart';

class SettingsSearchDock extends StatelessWidget {
  const SettingsSearchDock({
    super.key,
    required this.insidePaper,
    required this.controller,
    required this.focusNode,
    required this.focused,
  });

  final bool insidePaper;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = insidePaper ? 12.0 : 16.0;
    return SizedBox(
      key: Key(
        insidePaper
            ? 'settings_search_inside_paper'
            : 'settings_search_outside_paper',
      ),
      height: insidePaper ? 56 : 64,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _SettingsSearchField(
              controller: controller,
              focusNode: focusNode,
              focused: focused,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          key: const Key('settings_search_placeholder'),
          height: 44,
          child: AnimatedContainer(
            key: const Key('settings_search_field_surface'),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: surfaces.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: focused ? scheme.primary : surfaces.subtleDivider,
                width: focused ? 2 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: dark ? 0.24 : 0.18,
                        ),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  FleurIcons.search,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: l10n.settingsSearchHint,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyMedium,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                if (controller.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: controller.clear,
                      icon: const Icon(FleurIcons.close, size: 16),
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onPrimary,
                        backgroundColor: scheme.onSurfaceVariant,
                        fixedSize: const Size.square(30),
                        minimumSize: const Size.square(30),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsSearchResultsBody extends StatelessWidget {
  const SettingsSearchResultsBody({
    super.key,
    required this.query,
    required this.results,
    required this.tabLabels,
    required this.onSelected,
  });

  final String query;
  final List<SettingsSearchEntry> results;
  final Map<SettingsTab, String> tabLabels;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = <SettingsTab, List<SettingsSearchEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.tab, () => []).add(entry);
    }

    return SettingsPageBody(
      key: const Key('settings_search_results_body'),
      maxWidth: 760,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: results.isEmpty
          ? [const _SettingsSearchEmptyState()]
          : [
              for (final group in grouped.entries)
                _SettingsSearchResultGroup(
                  title: tabLabels[group.key] ?? group.key.queryValue,
                  query: query,
                  results: group.value,
                  onSelected: onSelected,
                ),
            ],
    );
  }
}

class _SettingsSearchEmptyState extends StatelessWidget {
  const _SettingsSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      key: const Key('settings_search_no_results'),
      padding: const EdgeInsets.symmetric(vertical: 88),
      child: Column(
        children: [
          Icon(FleurIcons.search, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            l10n.settingsSearchNoResults,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSearchResultGroup extends StatelessWidget {
  const _SettingsSearchResultGroup({
    required this.title,
    required this.query,
    required this.results,
    required this.onSelected,
  });

  final String title;
  final String query;
  final List<SettingsSearchEntry> results;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SettingsSearchCountBadge(
                label: l10n.settingsSearchResultCount(results.length),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaces.subtleDivider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  for (var index = 0; index < results.length; index++) ...[
                    if (index > 0)
                      Divider(height: 1, color: surfaces.subtleDivider),
                    _SettingsSearchResultRow(
                      entry: results[index],
                      query: query,
                      path: _settingsSearchEntryPath(
                        l10n,
                        title,
                        results[index],
                      ),
                      onSelected: onSelected,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSearchCountBadge extends StatelessWidget {
  const _SettingsSearchCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: dark ? 0.28 : 0.42),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: dark ? Colors.amber.shade100 : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchResultRow extends StatelessWidget {
  const _SettingsSearchResultRow({
    required this.entry,
    required this.query,
    required this.path,
    required this.onSelected,
  });

  final SettingsSearchEntry entry;
  final String query;
  final String path;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final pathStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_search_result_${entry.id}'),
        onTap: () => onSelected(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaces.cardSelected,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    settingsSearchEntryIcon(entry),
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: _settingsSearchHighlightSpans(
                          entry.title,
                          query,
                          titleStyle,
                          _settingsSearchHighlightStyle(titleStyle, context),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: _settingsSearchHighlightSpans(
                          path,
                          query,
                          pathStyle,
                          _settingsSearchHighlightStyle(pathStyle, context),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(FleurIcons.expand, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _settingsSearchEntryPath(
  AppLocalizations l10n,
  String tabLabel,
  SettingsSearchEntry entry,
) {
  if (entry.kind == SettingsSearchEntryKind.page) {
    return settingsSearchEntryKindLabel(l10n, entry.kind);
  }
  if (entry.section.isEmpty) return tabLabel;
  return '$tabLabel / ${entry.section}';
}

TextStyle _settingsSearchHighlightStyle(
  TextStyle? baseStyle,
  BuildContext context,
) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return (baseStyle ?? const TextStyle()).copyWith(
    backgroundColor: Colors.amber.withValues(alpha: dark ? 0.36 : 0.48),
    color: baseStyle?.color,
  );
}

List<TextSpan> _settingsSearchHighlightSpans(
  String text,
  String query,
  TextStyle? baseStyle,
  TextStyle highlightStyle,
) {
  final normalizedText = text.toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty || !normalizedText.contains(normalizedQuery)) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    final match = normalizedText.indexOf(normalizedQuery, cursor);
    if (match < 0) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
      break;
    }
    if (match > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match), style: baseStyle),
      );
    }
    final end = match + normalizedQuery.length;
    spans.add(
      TextSpan(text: text.substring(match, end), style: highlightStyle),
    );
    cursor = end;
  }
  return spans;
}
