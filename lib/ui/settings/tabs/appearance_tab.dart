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
      ReaderFontFamily.custom => l10n.custom,
    };
    String codeFontLabel(CodeFontFamilyPreset preset) => switch (preset) {
      CodeFontFamilyPreset.systemMono => l10n.codeFontSystemMono,
      CodeFontFamilyPreset.custom => l10n.custom,
    };
    String codeFontSizeModeLabel(CodeFontSizeMode mode) => switch (mode) {
      CodeFontSizeMode.followReader => l10n.codeFontSizeFollowReader,
      CodeFontSizeMode.oneStepDown => l10n.codeFontSizeOneStepDown,
      CodeFontSizeMode.custom => l10n.custom,
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
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsTargetAnchor(
                  id: 'appearance.reader.font_family',
                  controller: targetController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsControlRow(
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
                      if (readerSettings.fontFamily == ReaderFontFamily.custom)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _FontStackField(
                            key: const Key(
                              'appearance_reader_font_stack_field',
                            ),
                            inputKey: const Key(
                              'appearance_reader_font_stack_input',
                            ),
                            label: l10n.readerFontStack,
                            value: readerSettings.readerFontStack,
                            helperText: l10n.fontStackExample,
                            preview: _ReaderFontStackInlinePreview(
                              settings: readerSettings,
                            ),
                            onChanged: (value) => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setReaderFontStack(value),
                            ),
                          ),
                        ),
                    ],
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
        SettingsSection(
          title: l10n.codeAppearance,
          bottomSpacing: 0,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: _CodeAppearancePreview(settings: readerSettings),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.code.font',
                  controller: targetController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsControlRow(
                        title: Text(l10n.codeFontFamily),
                        controlWidth: 244,
                        control: _ReaderOptionWrap(
                          children: [
                            for (final preset in CodeFontFamilyPreset.values)
                              _PreviewChoiceCard(
                                key: Key(
                                  'appearance_code_font_${preset.name}_card',
                                ),
                                label: codeFontLabel(preset),
                                selected:
                                    readerSettings.codeFontFamily == preset,
                                width: 118,
                                onTap: () => unawaited(
                                  ref
                                      .read(readerSettingsProvider.notifier)
                                      .setCodeFontFamily(preset),
                                ),
                                preview: _CodeFontOptionPreview(
                                  settings: readerSettings,
                                  preset: preset,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (readerSettings.codeFontFamily ==
                          CodeFontFamilyPreset.custom)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _FontStackField(
                            key: const Key('appearance_code_font_stack_field'),
                            inputKey: const Key(
                              'appearance_code_font_stack_input',
                            ),
                            label: l10n.codeFontStack,
                            value: readerSettings.codeFontStack,
                            helperText: l10n.fontStackExample,
                            preview: _CodeFontStackInlinePreview(
                              settings: readerSettings,
                            ),
                            onChanged: (value) => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setCodeFontStack(value),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.code.font_size',
                  controller: targetController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsControlRow(
                        title: Text(l10n.codeFontSize),
                        controlWidth: 392,
                        control: _ReaderOptionWrap(
                          children: [
                            for (final mode in CodeFontSizeMode.values)
                              _PreviewChoiceCard(
                                key: Key(
                                  'appearance_code_font_size_${mode.name}_card',
                                ),
                                label: codeFontSizeModeLabel(mode),
                                selected:
                                    readerSettings.codeFontSizeMode == mode,
                                width: 124,
                                onTap: () => unawaited(
                                  ref
                                      .read(readerSettingsProvider.notifier)
                                      .setCodeFontSizeMode(mode),
                                ),
                                preview: _CodeFontSizeModePreview(
                                  settings: readerSettings,
                                  mode: mode,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (readerSettings.codeFontSizeMode ==
                          CodeFontSizeMode.custom)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: SettingsSliderControl(
                            key: const Key('appearance_code_font_size_slider'),
                            value: readerSettings.codeFontSize,
                            min: 11,
                            max: 24,
                            format: (v) => v.toStringAsFixed(0),
                            valueLabel:
                                '${l10n.codeFontSize} ${readerSettings.codeFontSize.toStringAsFixed(0)}',
                            onChanged: (value) => unawaited(
                              ref
                                  .read(readerSettingsProvider.notifier)
                                  .setCodeFontSize(value),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.code.line_height',
                  controller: targetController,
                  child: SliderTile(
                    key: const Key('appearance_code_line_height_slider'),
                    title: l10n.codeLineHeight,
                    value: readerSettings.codeLineHeight,
                    min: 1.1,
                    max: 2.0,
                    format: (v) => v.toStringAsFixed(2),
                    onChanged: (v) => unawaited(
                      ref
                          .read(readerSettingsProvider.notifier)
                          .setCodeLineHeight(v),
                    ),
                  ),
                ),
                SettingsTargetAnchor(
                  id: 'appearance.code.wrap',
                  controller: targetController,
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
                SettingsControlRow(
                  title: Text(l10n.codeAppearance),
                  control: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SettingsActionButton(
                      key: const Key('appearance_code_reset_button'),
                      onPressed: () => unawaited(
                        ref
                            .read(readerSettingsProvider.notifier)
                            .resetCodeAppearance(),
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

class _FontStackField extends StatefulWidget {
  const _FontStackField({
    super.key,
    required this.label,
    required this.value,
    required this.helperText,
    required this.preview,
    required this.onChanged,
    required this.inputKey,
  });

  final String label;
  final String value;
  final String helperText;
  final Widget preview;
  final ValueChanged<String> onChanged;
  final Key inputKey;

  @override
  State<_FontStackField> createState() => _FontStackFieldState();
}

class _FontStackFieldState extends State<_FontStackField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _FontStackField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          key: widget.inputKey,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 10),
        widget.preview,
      ],
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
      settings: settings.copyWith(
        fontFamily: family,
        readerFontStack: family == ReaderFontFamily.custom
            ? settings.readerFontStack
            : '',
      ),
    );
    final reader = previewTheme.fleurReader;

    return Theme(
      data: previewTheme,
      child: Text(
        family == ReaderFontFamily.custom ? 'Aa*' : 'Aa',
        style: reader.bodyStyle.copyWith(
          fontSize: family == ReaderFontFamily.custom ? 22 : 24,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReaderFontStackInlinePreview extends StatelessWidget {
  const _ReaderFontStackInlinePreview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings,
    );
    final reader = previewTheme.fleurReader;
    final surfaces = previewTheme.fleurSurface;

    return Theme(
      data: previewTheme,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: surfaces.subtleDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            '雨落在窗前 Reading quietly 2026',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.bodyStyle.copyWith(
              fontSize: 16,
              height: 1.35,
              color: previewTheme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeAppearancePreview extends StatelessWidget {
  const _CodeAppearancePreview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings,
    );
    final reader = previewTheme.fleurReader;
    final scheme = previewTheme.colorScheme;
    final surfaces = previewTheme.fleurSurface;

    return Theme(
      data: previewTheme,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: reader.codeBlockSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: surfaces.subtleDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'const value = await loadArticle();',
            maxLines: settings.codeSoftWrap ? 3 : 1,
            overflow: settings.codeSoftWrap
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            softWrap: settings.codeSoftWrap,
            style: reader.codeStyle.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _CodeFontOptionPreview extends StatelessWidget {
  const _CodeFontOptionPreview({required this.settings, required this.preset});

  final ReaderSettings settings;
  final CodeFontFamilyPreset preset;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings.copyWith(codeFontFamily: preset),
    );
    final reader = previewTheme.fleurReader;

    return Text(
      '{}',
      style: reader.codeStyle.copyWith(
        fontSize: 20,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CodeFontSizeModePreview extends StatelessWidget {
  const _CodeFontSizeModePreview({required this.settings, required this.mode});

  final ReaderSettings settings;
  final CodeFontSizeMode mode;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings.copyWith(codeFontSizeMode: mode),
    );
    final reader = previewTheme.fleurReader;

    return Text(
      '12',
      style: reader.codeStyle.copyWith(
        fontSize: (reader.codeStyle.fontSize ?? 14).clamp(13, 22).toDouble(),
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CodeFontStackInlinePreview extends StatelessWidget {
  const _CodeFontStackInlinePreview({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.readerScene(
      Theme.of(context),
      settings: settings,
    );
    final reader = previewTheme.fleurReader;
    final surfaces = previewTheme.fleurSurface;

    return Theme(
      data: previewTheme,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: reader.codeBlockSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: surfaces.subtleDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            'const value = await loadArticle();',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.codeStyle,
          ),
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
