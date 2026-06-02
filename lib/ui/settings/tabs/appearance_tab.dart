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
      ReaderThemePreset.dark => l10n.readerThemeDark,
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
          title: l10n.appearancePreview,
          child: _AppearancePreviewCard(settings: readerSettings),
        ),
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
                    control: SettingsSelectField<ReaderFontFamily>(
                      key: const Key('appearance_reader_font_family_select'),
                      value: readerSettings.fontFamily,
                      options: [
                        for (final family in ReaderFontFamily.values)
                          SettingsSelectOption(
                            value: family,
                            label: Text(readerFontLabel(family)),
                          ),
                      ],
                      onChanged: (value) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setFontFamily(value),
                      ),
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
                    controlWidth: 320,
                    control: SegmentedButton<ReaderContentWidthPreset>(
                      key: const Key('appearance_reader_width_segmented'),
                      segments: [
                        for (final preset in ReaderContentWidthPreset.values)
                          ButtonSegment(
                            value: preset,
                            label: Text(readingWidthLabel(preset)),
                          ),
                      ],
                      selected: {readerSettings.contentWidthPreset},
                      onSelectionChanged: (selected) {
                        if (selected.isEmpty) return;
                        unawaited(
                          ref
                              .read(readerSettingsProvider.notifier)
                              .setContentWidthPreset(selected.first),
                        );
                      },
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.reader.theme',
                  controller: targetController,
                  child: SettingsControlRow(
                    title: Text(l10n.readerTheme),
                    control: SettingsSelectField<ReaderThemePreset>(
                      key: const Key('appearance_reader_theme_select'),
                      value: readerSettings.readerTheme,
                      options: [
                        for (final preset in ReaderThemePreset.values)
                          SettingsSelectOption(
                            value: preset,
                            label: Text(readerThemeLabel(preset)),
                          ),
                      ],
                      onChanged: (value) => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .setReaderTheme(value),
                      ),
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

class _AppearancePreviewCard extends StatelessWidget {
  const _AppearancePreviewCard({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final baseTheme = Theme.of(context);
    final previewTheme = AppTheme.readerScene(baseTheme, settings: settings);
    final reader = previewTheme.fleurReader;
    final surfaces = previewTheme.fleurSurface;
    final scheme = previewTheme.colorScheme;

    return Theme(
      data: previewTheme,
      child: SettingsCard(
        key: const Key('appearance_preview_card'),
        color: surfaces.reader,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : reader.maxWidth;
            final measure = width.clamp(280, reader.maxWidth).toDouble();

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: measure),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appearancePreviewTitle,
                      style: reader.titleStyleForBodyFontSize(
                        settings.fontSize,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.appearancePreviewMeta, style: reader.metaStyle),
                    const SizedBox(height: 14),
                    Text(
                      l10n.appearancePreviewBody,
                      style: reader.bodyStyle.copyWith(
                        fontSize: settings.fontSize,
                        height: settings.lineHeight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        top: 8,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: reader.blockquoteAccent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        l10n.appearancePreviewQuote,
                        style: reader.bodyStyle.copyWith(
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.appearancePreviewLink,
                          style: reader.bodyStyle.copyWith(
                            color: scheme.primary,
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
                            decoration: TextDecoration.underline,
                            decorationColor: scheme.primary,
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: reader.codeBlockSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              l10n.appearancePreviewCode,
                              style: reader.bodyStyle.copyWith(
                                fontSize: (settings.fontSize - 1).clamp(12, 24),
                                height: 1.35,
                                fontFamily: 'SF Mono',
                                fontFamilyFallback: const [
                                  'Menlo',
                                  'Consolas',
                                  'monospace',
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
