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
import '../settings_targets.dart';
import '../widgets/section_header.dart';
import '../widgets/slider_tile.dart';

class AppearanceTab extends ConsumerWidget {
  const AppearanceTab({
    super.key,
    required this.targetController,
    this.showPageTitle = true,
  });

  final SettingsTargetController targetController;
  final bool showPageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
    String readerFontLabel(ReaderFontFamily family) => switch (family) {
      ReaderFontFamily.system => l10n.readerFontSystem,
      ReaderFontFamily.serif => l10n.readerFontSerif,
      ReaderFontFamily.sans => l10n.readerFontSans,
      ReaderFontFamily.mono => l10n.readerFontMono,
    };
    String readerThemeLabel(ReaderThemePreset preset) => switch (preset) {
      ReaderThemePreset.defaultLightAware => l10n.readerThemeDefault,
      ReaderThemePreset.paper => l10n.readerThemePaper,
      ReaderThemePreset.sepia => l10n.readerThemeSepia,
      ReaderThemePreset.dim => l10n.readerThemeDim,
    };
    String readingWidthLabel(ReaderContentWidthPreset preset) =>
        switch (preset) {
          ReaderContentWidthPreset.narrow => l10n.readingWidthNarrow,
          ReaderContentWidthPreset.standard => l10n.readingWidthStandard,
          ReaderContentWidthPreset.wide => l10n.readingWidthWide,
        };

    final currentBrightness = theme.brightness;
    final dynamicColorAvailable = theme.fleurDynamicColor.available;
    final showManualColors =
        !dynamicColorAvailable || !appSettings.useDynamicColor;

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
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
                controller: targetController,
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
                controller: targetController,
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
                                child: _ThemeColorCard(
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
          bottomSpacing: 0,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsTargetAnchor(
                  id: 'appearance.reader.font_family',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readerFontFamily),
                    controlWidth: 456,
                    control: _ReaderOptionWrap(
                      children: [
                        for (final family in ReaderFontFamily.values)
                          _PreviewChoiceCard(
                            key: Key(
                              'appearance_reader_font_${family.name}_card',
                            ),
                            label: readerFontLabel(family),
                            selected: readerSettings.fontFamily == family,
                            width: 108,
                            onTap: () => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setFontFamily(family),
                            ),
                            preview: _ReaderFontOptionPreview(
                              settings: readerSettings,
                              family: family,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.font_size',
                  controller: targetController,
                  child: SliderTile(
                    title: l10n.fontSize,
                    value: readerSettings.fontSize,
                    min: 12,
                    max: 28,
                    format: (v) => v.toStringAsFixed(0),
                    onChanged: (v) => unawaited(
                      ref.read(readerSettingsProvider.notifier).setFontSize(v),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.line_height',
                  controller: targetController,
                  child: SliderTile(
                    title: l10n.lineHeight,
                    value: readerSettings.lineHeight,
                    min: 1.1,
                    max: 2.2,
                    format: (v) => v.toStringAsFixed(1),
                    onChanged: (v) => unawaited(
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setLineHeight(v),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.width',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readingWidth),
                    controlWidth: 420,
                    control: _ReaderOptionWrap(
                      children: [
                        for (final preset in ReaderContentWidthPreset.values)
                          _PreviewChoiceCard(
                            key: Key(
                              'appearance_reader_width_${preset.name}_card',
                            ),
                            label: readingWidthLabel(preset),
                            selected:
                                readerSettings.contentWidthPreset == preset,
                            width: 132,
                            onTap: () => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setContentWidthPreset(preset),
                            ),
                            preview: _ReadingWidthOptionPreview(preset: preset),
                          ),
                      ],
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.theme',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readerTheme),
                    controlWidth: 456,
                    control: _ReaderOptionWrap(
                      children: [
                        for (final preset in ReaderThemePreset.values)
                          _PreviewChoiceCard(
                            key: Key(
                              'appearance_reader_theme_${preset.name}_card',
                            ),
                            label: readerThemeLabel(preset),
                            selected: readerSettings.readerTheme == preset,
                            width: 84,
                            onTap: () => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setReaderTheme(preset),
                            ),
                            preview: _ReaderThemeOptionPreview(
                              settings: readerSettings,
                              preset: preset,
                            ),
                          ),
                      ],
                    ),
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

class _ReaderOptionWrap extends StatelessWidget {
  const _ReaderOptionWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _PreviewChoiceCard extends StatelessWidget {
  const _PreviewChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
    required this.width,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final borderColor = selected ? scheme.primary : surfaces.subtleDivider;
    final backgroundColor = selected
        ? scheme.primaryContainer.withValues(alpha: 0.18)
        : surfaces.card;
    final labelColor = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: SizedBox(
          width: width,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 78),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 38, child: Center(child: preview)),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: labelColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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

class _ReaderFontOptionPreview extends StatelessWidget {
  const _ReaderFontOptionPreview({
    required this.settings,
    required this.family,
  });

  final ReaderSettings settings;
  final ReaderFontFamily family;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings.copyWith(fontFamily: family),
    );
    final reader = previewTheme.fleurReader;

    return Theme(
      data: previewTheme,
      child: Text(
        'Aa',
        style: reader.bodyStyle.copyWith(
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReadingWidthOptionPreview extends StatelessWidget {
  const _ReadingWidthOptionPreview({required this.preset});

  final ReaderContentWidthPreset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final width = switch (preset) {
      ReaderContentWidthPreset.narrow => 38.0,
      ReaderContentWidthPreset.standard => 52.0,
      ReaderContentWidthPreset.wide => 68.0,
    };
    final lineColor = scheme.primary;
    final mutedLineColor = scheme.onSurfaceVariant.withValues(alpha: 0.42);

    return SizedBox(
      width: 82,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.reader,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: surfaces.subtleDivider),
        ),
        child: Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewLine(color: lineColor, widthFactor: 0.9),
                const SizedBox(height: 4),
                _PreviewLine(color: mutedLineColor),
                const SizedBox(height: 4),
                _PreviewLine(color: mutedLineColor, widthFactor: 0.78),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderThemeOptionPreview extends StatelessWidget {
  const _ReaderThemeOptionPreview({
    required this.settings,
    required this.preset,
  });

  final ReaderSettings settings;
  final ReaderThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings.copyWith(readerTheme: preset),
    );
    final scheme = previewTheme.colorScheme;
    final reader = previewTheme.fleurReader;
    final surfaces = previewTheme.fleurSurface;

    return Theme(
      data: previewTheme,
      child: SizedBox(
        width: 58,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.reader,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: surfaces.subtleDivider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewLine(color: scheme.primary, widthFactor: 0.54),
                const SizedBox(height: 4),
                _PreviewLine(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 5,
                      decoration: BoxDecoration(
                        color: reader.blockquoteAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _PreviewLine(
                        color: reader.codeBlockSurface,
                        widthFactor: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.color, this.widthFactor = 1});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ThemeColorCard extends StatelessWidget {
  const _ThemeColorCard({
    super.key,
    required this.selected,
    required this.scheme,
    required this.onTap,
    this.semanticLabel,
  });

  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const tapSize = 72.0;
    const swatchSize = 54.0;
    final selectedColor = Theme.of(context).colorScheme.primary;
    final onSelectedColor = Theme.of(context).colorScheme.onPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: SizedBox(
        width: tapSize,
        height: tapSize,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            radius: tapSize / 2,
            child: Stack(
              children: [
                Center(
                  child: CustomPaint(
                    size: const Size.square(swatchSize),
                    painter: _SchemeSwatchPainter(
                      scheme,
                      outlineColor: selected ? selectedColor : scheme.outline,
                      outlineWidth: selected ? 4 : 2,
                    ),
                  ),
                ),
                if (selected)
                  Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FleurIcons.check,
                        size: 18,
                        color: onSelectedColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemeSwatchPainter extends CustomPainter {
  const _SchemeSwatchPainter(
    this.scheme, {
    required this.outlineColor,
    required this.outlineWidth,
  });

  final ColorScheme scheme;
  final Color outlineColor;
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    final clip = Path()..addOval(rect);
    canvas.save();
    canvas.clipPath(clip);

    paint.color = scheme.primary;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), paint);

    paint.color = scheme.secondary;
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height / 2),
      paint,
    );

    paint.color = scheme.tertiary;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2,
        size.width / 2,
        size.height / 2,
      ),
      paint,
    );

    canvas.restore();

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth
      ..color = outlineColor;
    canvas.drawOval(rect.deflate(1), stroke);
  }

  @override
  bool shouldRepaint(covariant _SchemeSwatchPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}
