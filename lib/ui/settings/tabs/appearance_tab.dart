import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/settings/reader_settings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/fleur_color_engine.dart';
import '../../../theme/fleur_icons.dart';
import '../../../theme/fleur_theme_extensions.dart';
import '../../../theme/seed_color_presets.dart';
import '../appearance/appearance_fonts_page.dart';
import '../appearance/appearance_preview_options.dart';
import '../appearance/appearance_theme_color_card.dart';
import '../settings_targets.dart';
import '../widgets/settings_controls.dart';

enum AppearanceDetailPage { fonts }

enum _ReaderLineHeightPreset { compact, standard, relaxed }

const _visibleReaderFontFamilies = [
  ReaderFontFamily.system,
  ReaderFontFamily.serif,
  ReaderFontFamily.sans,
  ReaderFontFamily.mono,
];

class AppearanceTab extends ConsumerStatefulWidget {
  const AppearanceTab({
    super.key,
    required this.targetController,
    required this.detailPage,
    required this.onOpenFontsDetail,
    required this.onCloseDetail,
    this.showPageTitle = true,
  });

  final SettingsTargetController targetController;
  final AppearanceDetailPage? detailPage;
  final VoidCallback onOpenFontsDetail;
  final VoidCallback onCloseDetail;
  final bool showPageTitle;

  @override
  ConsumerState<AppearanceTab> createState() => _AppearanceTabState();
}

class _AppearanceTabState extends ConsumerState<AppearanceTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (widget.detailPage == AppearanceDetailPage.fonts) {
      return AppearanceFontsPage(onBack: widget.onCloseDetail);
    }

    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? AppSettings.defaults();
    final readerSettings =
        ref.watch(readerSettingsProvider).valueOrNull ?? const ReaderSettings();

    String seedPresetLabel(SeedColorPreset p) => switch (p) {
      SeedColorPreset.blue => l10n.seedColorBlue,
      SeedColorPreset.green => l10n.seedColorGreen,
      SeedColorPreset.purple => l10n.seedColorPurple,
      SeedColorPreset.orange => l10n.seedColorOrange,
      SeedColorPreset.pink => l10n.seedColorPink,
    };

    final currentBrightness = theme.brightness;
    final dynamicColorAvailable = theme.fleurDynamicColor.available;
    final showManualColors =
        !dynamicColorAvailable || !appSettings.useDynamicColor;

    return SettingsPageBody(
      children: [
        if (widget.showPageTitle) ...[
          SectionHeader(title: l10n.appearance),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.applicationAppearance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsTargetAnchor(
                id: 'appearance.theme.mode',
                controller: widget.targetController,
                child: SettingsCard(
                  padding: EdgeInsets.zero,
                  child: SettingsControlRow(
                    title: Text(l10n.themeMode),
                    controlWidth: 360,
                    control: SegmentedButton<ThemeMode>(
                      key: const Key('appearance_theme_mode_segmented'),
                      segments: [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text(l10n.system),
                          icon: const Icon(FleurIcons.themeSystem),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text(l10n.light),
                          icon: const Icon(FleurIcons.themeLight),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text(l10n.dark),
                          icon: const Icon(FleurIcons.themeDark),
                        ),
                      ],
                      selected: {appSettings.themeMode},
                      onSelectionChanged: (selected) {
                        if (selected.isEmpty) return;
                        unawaited(
                          ref
                              .read(appSettingsProvider.notifier)
                              .setThemeMode(selected.first),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SettingsTargetAnchor(
                id: 'appearance.theme.colors',
                controller: widget.targetController,
                child: SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.seedColorPreset,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          SettingsIconActionButton(
                            tooltip: l10n.resetToDefault,
                            onPressed: () {
                              unawaited(
                                ref
                                    .read(appSettingsProvider.notifier)
                                    .save(
                                      appSettings.copyWith(
                                        themeMode: ThemeMode.system,
                                        useDynamicColor: true,
                                        seedColorPreset: SeedColorPreset.blue,
                                      ),
                                    ),
                              );
                            },
                            icon: FleurIcons.reset,
                          ),
                        ],
                      ),
                      if (dynamicColorAvailable) ...[
                        const SizedBox(height: 12),
                        SettingsSwitchTile(
                          key: const Key('appearance_dynamic_color_switch'),
                          title: Text(l10n.dynamicColor),
                          subtitle: Text(l10n.dynamicColorSubtitle),
                          value: appSettings.useDynamicColor,
                          onChanged: (v) {
                            unawaited(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setUseDynamicColor(v),
                            );
                          },
                          secondary: const Icon(FleurIcons.colorPicker),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      if (showManualColors) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final p in SeedColorPreset.values)
                              Tooltip(
                                message: seedPresetLabel(p),
                                child: AppearanceThemeColorCard(
                                  key: Key(
                                    'appearance_seed_color_${p.name}_card',
                                  ),
                                  selected: appSettings.seedColorPreset == p,
                                  scheme: FleurColorEngine.resolve(
                                    brightness: currentBrightness,
                                    seedColorPreset: p,
                                  ).materialScheme,
                                  semanticLabel: seedPresetLabel(p),
                                  onTap: () {
                                    unawaited(
                                      ref
                                          .read(appSettingsProvider.notifier)
                                          .save(
                                            appSettings.copyWith(
                                              useDynamicColor: false,
                                              seedColorPreset: p,
                                            ),
                                          ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.seedColorPresetSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
          title: l10n.readerAppearance,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsTargetAnchor(
                  id: 'appearance.reader.font_family',
                  controller: widget.targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readerFontFamily),
                    controlWidth: 560,
                    control: AppearancePreviewOptionGroup<ReaderFontFamily>(
                      key: const Key('appearance_reader_font_family_options'),
                      value: _visibleReaderFontFamily(readerSettings),
                      options: [
                        for (final family in _visibleReaderFontFamilies)
                          AppearancePreviewOption(
                            key: Key(
                              'appearance_reader_font_family_${family.name}_option',
                            ),
                            value: family,
                            semanticLabel: _readerFontLabel(l10n, family),
                            width: 128,
                            minHeight: 82,
                            child: _ReaderFontFamilyPreview(
                              label: _readerFontLabel(l10n, family),
                              settings: readerSettings.copyWith(
                                fontFamily: family,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (family) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setFontFamily(family),
                      ),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.font_size',
                  controller: widget.targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.fontSize),
                    controlWidth: 520,
                    control: AppearancePreviewOptionGroup<ReaderFontSizePreset>(
                      key: const Key('appearance_reader_font_size_options'),
                      value: ReaderFontSizePreset.fromFontSize(
                        readerSettings.fontSize,
                      ),
                      options: [
                        for (final preset in ReaderFontSizePreset.values)
                          AppearancePreviewOption(
                            key: Key(
                              'appearance_reader_font_size_${preset.name}_option',
                            ),
                            value: preset,
                            semanticLabel: _fontSizePresetLabel(l10n, preset),
                            width: 92,
                            minHeight: 74,
                            child: _FontSizePresetPreview(
                              label: _fontSizePresetLabel(l10n, preset),
                              fontSize: preset.fontSize,
                            ),
                          ),
                      ],
                      onChanged: (preset) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setFontSize(preset.fontSize),
                      ),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.line_height',
                  controller: widget.targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.lineHeight),
                    controlWidth: 360,
                    control: AppearancePreviewOptionGroup<_ReaderLineHeightPreset>(
                      key: const Key('appearance_reader_line_height_options'),
                      value: _lineHeightPresetFor(readerSettings.lineHeight),
                      options: [
                        for (final preset in _ReaderLineHeightPreset.values)
                          AppearancePreviewOption(
                            key: Key(
                              'appearance_reader_line_height_${preset.name}_option',
                            ),
                            value: preset,
                            semanticLabel: _lineHeightPresetLabel(l10n, preset),
                            width: 104,
                            child: _LineHeightPresetPreview(
                              label: _lineHeightPresetLabel(l10n, preset),
                              lineHeight: _lineHeightPresetValue(preset),
                            ),
                          ),
                      ],
                      onChanged: (preset) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setLineHeight(_lineHeightPresetValue(preset)),
                      ),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.width',
                  controller: widget.targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readingWidth),
                    controlWidth: 360,
                    control:
                        AppearancePreviewOptionGroup<ReaderContentWidthPreset>(
                          key: const Key('appearance_reader_width_options'),
                          value: readerSettings.contentWidthPreset,
                          options: [
                            for (final preset
                                in ReaderContentWidthPreset.values)
                              AppearancePreviewOption(
                                key: Key(
                                  'appearance_reader_width_${preset.name}_option',
                                ),
                                value: preset,
                                semanticLabel: _readingWidthLabel(l10n, preset),
                                width: 104,
                                child: _ReadingWidthPresetPreview(
                                  label: _readingWidthLabel(l10n, preset),
                                  preset: preset,
                                ),
                              ),
                          ],
                          onChanged: (preset) {
                            unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setContentWidthPreset(preset),
                            );
                          },
                        ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.theme',
                  controller: widget.targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readerTheme),
                    controlWidth: 500,
                    control: AppearancePreviewOptionGroup<ReaderThemePreset>(
                      key: const Key('appearance_reader_theme_options'),
                      value: readerSettings.readerTheme,
                      options: [
                        for (final preset in ReaderThemePreset.values)
                          AppearancePreviewOption(
                            key: Key(
                              'appearance_reader_theme_${preset.name}_option',
                            ),
                            value: preset,
                            semanticLabel: _readerThemeLabel(l10n, preset),
                            width: 112,
                            child: _ReaderTexturePresetPreview(
                              label: _readerThemeLabel(l10n, preset),
                              settings: readerSettings.copyWith(
                                readerTheme: preset,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (preset) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setReaderTheme(preset),
                      ),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.code.wrap',
                  controller: widget.targetController,
                  child: SettingsSwitchTile(
                    key: const Key('appearance_code_soft_wrap_switch'),
                    title: Text(l10n.codeSoftWrap),
                    value: readerSettings.codeSoftWrap,
                    onChanged: (value) => unawaited(
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setCodeSoftWrap(value),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.fonts.advanced',
                  controller: widget.targetController,
                  child: SettingsTile(
                    key: const Key('appearance_advanced_fonts_tile'),
                    title: Text(l10n.advancedFontSettings),
                    trailing: _DisclosureTrailing(
                      summary: appearanceFontSettingsSummary(
                        l10n,
                        readerSettings,
                      ),
                    ),
                    onTap: widget.onOpenFontsDetail,
                  ),
                ),
                SettingsControlRow(
                  title: Text(l10n.readerAppearance),
                  control: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SettingsActionButton(
                      key: const Key('appearance_reader_reset_button'),
                      onPressed: () => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .resetReaderAppearance(),
                      ),
                      icon: const Icon(FleurIcons.reset),
                      label: Text(l10n.resetToDefault),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DisclosureTrailing extends StatelessWidget {
  const _DisclosureTrailing({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          FleurIcons.chevronRight,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _FontSizePresetPreview extends StatelessWidget {
  const _FontSizePresetPreview({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: Center(
            child: Text(
              'Aa',
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: fontSize,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineHeightPresetPreview extends StatelessWidget {
  const _LineHeightPresetPreview({
    required this.label,
    required this.lineHeight,
  });

  final String label;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reading\n阅读',
          maxLines: 2,
          overflow: TextOverflow.clip,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            height: lineHeight,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
        ),
      ],
    );
  }
}

class _ReadingWidthPresetPreview extends StatelessWidget {
  const _ReadingWidthPresetPreview({required this.label, required this.preset});

  final String label;
  final ReaderContentWidthPreset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widthFactor = switch (preset) {
      ReaderContentWidthPreset.narrow => 0.58,
      ReaderContentWidthPreset.standard => 0.76,
      ReaderContentWidthPreset.wide => 0.96,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 30,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Container(
                  key: Key('appearance_reader_width_${preset.name}_measure'),
                  width: constraints.maxWidth * widthFactor,
                  height: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.36),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreviewLine(widthFactor: 1, color: scheme.primary),
                      _PreviewLine(
                        widthFactor: 0.88,
                        color: scheme.onSurfaceVariant,
                      ),
                      _PreviewLine(
                        widthFactor: 0.68,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
        ),
      ],
    );
  }
}

class _ReaderTexturePresetPreview extends StatelessWidget {
  const _ReaderTexturePresetPreview({
    required this.label,
    required this.settings,
  });

  final String label;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings,
    );
    final scheme = previewTheme.colorScheme;
    final surfaces = previewTheme.fleurSurface;
    final reader = previewTheme.fleurReader;

    return Theme(
      data: previewTheme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.reader,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: surfaces.subtleDivider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewLine(widthFactor: 0.82, color: scheme.onSurface),
                  const SizedBox(height: 5),
                  _PreviewLine(
                    widthFactor: 0.64,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 13,
                        decoration: BoxDecoration(
                          color: reader.blockquoteAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _PreviewLine(
                          widthFactor: 0.72,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: previewTheme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderFontFamilyPreview extends StatelessWidget {
  const _ReaderFontFamilyPreview({required this.label, required this.settings});

  final String label;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings,
    );
    final reader = previewTheme.fleurReader;

    return Theme(
      data: previewTheme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '雨落在窗前',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.bodyStyle.copyWith(fontSize: 13, height: 1.2),
          ),
          Text(
            'Reading quietly 2026',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.bodyStyle.copyWith(fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: previewTheme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.widthFactor, required this.color});

  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.0, 1.0).toDouble(),
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const SizedBox(height: 3),
      ),
    );
  }
}

String _readerFontLabel(AppLocalizations l10n, ReaderFontFamily family) {
  return switch (family) {
    ReaderFontFamily.system => l10n.readerFontSystem,
    ReaderFontFamily.serif => l10n.readerFontSerif,
    ReaderFontFamily.sans => l10n.readerFontSans,
    ReaderFontFamily.mono => l10n.readerFontMono,
    ReaderFontFamily.custom => l10n.custom,
  };
}

String _readerThemeLabel(AppLocalizations l10n, ReaderThemePreset preset) {
  return switch (preset) {
    ReaderThemePreset.defaultLightAware => l10n.readerThemeDefault,
    ReaderThemePreset.paper => l10n.readerThemePaper,
    ReaderThemePreset.sepia => l10n.readerThemeSepia,
    ReaderThemePreset.dim => l10n.readerThemeDim,
  };
}

ReaderFontFamily _visibleReaderFontFamily(ReaderSettings settings) {
  return settings.fontFamily == ReaderFontFamily.custom
      ? ReaderFontFamily.system
      : settings.fontFamily;
}

String _readingWidthLabel(
  AppLocalizations l10n,
  ReaderContentWidthPreset preset,
) {
  return switch (preset) {
    ReaderContentWidthPreset.narrow => l10n.readingWidthNarrow,
    ReaderContentWidthPreset.standard => l10n.readingWidthStandard,
    ReaderContentWidthPreset.wide => l10n.readingWidthWide,
  };
}

String _fontSizePresetLabel(
  AppLocalizations l10n,
  ReaderFontSizePreset preset,
) {
  return switch (preset) {
    ReaderFontSizePreset.extraSmall => l10n.fontSizeExtraSmall,
    ReaderFontSizePreset.small => l10n.fontSizeSmall,
    ReaderFontSizePreset.medium => l10n.fontSizeMediumRecommended,
    ReaderFontSizePreset.large => l10n.fontSizeLarge,
    ReaderFontSizePreset.extraLarge => l10n.fontSizeExtraLarge,
  };
}

_ReaderLineHeightPreset _lineHeightPresetFor(double value) {
  if (value <= 1.475) return _ReaderLineHeightPreset.compact;
  if (value <= 1.725) return _ReaderLineHeightPreset.standard;
  return _ReaderLineHeightPreset.relaxed;
}

double _lineHeightPresetValue(_ReaderLineHeightPreset preset) {
  return switch (preset) {
    _ReaderLineHeightPreset.compact => 1.35,
    _ReaderLineHeightPreset.standard => ReaderSettings.defaultLineHeight,
    _ReaderLineHeightPreset.relaxed => 1.85,
  };
}

String _lineHeightPresetLabel(
  AppLocalizations l10n,
  _ReaderLineHeightPreset preset,
) {
  return switch (preset) {
    _ReaderLineHeightPreset.compact => l10n.lineHeightCompact,
    _ReaderLineHeightPreset.standard => l10n.lineHeightStandard,
    _ReaderLineHeightPreset.relaxed => l10n.lineHeightRelaxed,
  };
}
