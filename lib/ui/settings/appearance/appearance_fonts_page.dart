import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/settings/reader_settings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/fleur_icons.dart';
import '../../../theme/fleur_theme_extensions.dart';
import '../widgets/settings_controls.dart';
import '../widgets/slider_tile.dart';
import 'appearance_preview_options.dart';

class AppearanceFontsPage extends ConsumerWidget {
  const AppearanceFontsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings =
        ref.watch(readerSettingsProvider).valueOrNull ?? const ReaderSettings();
    final notifier = ref.read(readerSettingsProvider.notifier);

    return SettingsPageBody(
      children: [
        SettingsDetailHeader(
          title: l10n.advancedFontSettings,
          trailing: SettingsActionButton(
            key: const Key('appearance_fonts_back_button'),
            onPressed: onBack,
            icon: const Icon(FleurIcons.back),
            label: Text(l10n.back),
          ),
        ),
        SettingsSection(
          title: l10n.fontSize,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SliderTile(
                  key: const Key('appearance_reader_font_size_slider'),
                  title: l10n.fontSize,
                  value: settings.fontSize,
                  min: 12,
                  max: 28,
                  format: (value) => value.toStringAsFixed(0),
                  onChanged: (value) => unawaited(notifier.setFontSize(value)),
                ),
                SliderTile(
                  key: const Key('appearance_minimum_font_size_slider'),
                  title: l10n.minimumFontSize,
                  value: settings.minimumFontSize,
                  min: 10,
                  max: 18,
                  format: (value) => value.toStringAsFixed(0),
                  onChanged: (value) =>
                      unawaited(notifier.setMinimumFontSize(value)),
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          title: l10n.fontSettings,
          child: SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FontStackField(
                  key: const Key('appearance_standard_font_stack_field'),
                  inputKey: const Key('appearance_standard_font_stack_input'),
                  label: l10n.standardFont,
                  value: settings.standardFontStack,
                  helperText: l10n.fontStackExample,
                  preview: _ReaderFontStackInlinePreview(
                    settings: settings.copyWith(
                      fontFamily: ReaderFontFamily.system,
                    ),
                  ),
                  onChanged: (value) =>
                      unawaited(notifier.setStandardFontStack(value)),
                ),
                const SizedBox(height: 18),
                _FontStackField(
                  key: const Key('appearance_serif_font_stack_field'),
                  inputKey: const Key('appearance_serif_font_stack_input'),
                  label: l10n.serifFont,
                  value: settings.serifFontStack,
                  helperText: l10n.fontStackExample,
                  preview: _ReaderFontStackInlinePreview(
                    settings: settings.copyWith(
                      fontFamily: ReaderFontFamily.serif,
                    ),
                  ),
                  onChanged: (value) =>
                      unawaited(notifier.setSerifFontStack(value)),
                ),
                const SizedBox(height: 18),
                _FontStackField(
                  key: const Key('appearance_sans_font_stack_field'),
                  inputKey: const Key('appearance_sans_font_stack_input'),
                  label: l10n.sansSerifFont,
                  value: settings.sansFontStack,
                  helperText: l10n.fontStackExample,
                  preview: _ReaderFontStackInlinePreview(
                    settings: settings.copyWith(
                      fontFamily: ReaderFontFamily.sans,
                    ),
                  ),
                  onChanged: (value) =>
                      unawaited(notifier.setSansFontStack(value)),
                ),
                const SizedBox(height: 18),
                _FontStackField(
                  key: const Key('appearance_mono_font_stack_field'),
                  inputKey: const Key('appearance_mono_font_stack_input'),
                  label: l10n.fixedWidthFont,
                  value: settings.monoFontStack,
                  helperText: l10n.monoFontStackExample,
                  preview: _ReaderFontStackInlinePreview(
                    settings: settings.copyWith(
                      fontFamily: ReaderFontFamily.mono,
                    ),
                  ),
                  onChanged: (value) =>
                      unawaited(notifier.setMonoFontStack(value)),
                ),
                const SizedBox(height: 18),
                _FontStackField(
                  key: const Key('appearance_math_font_stack_field'),
                  inputKey: const Key('appearance_math_font_stack_input'),
                  label: l10n.mathFont,
                  value: settings.mathFontStack,
                  helperText: l10n.mathFontStackExample,
                  preview: _MathFontStackInlinePreview(settings: settings),
                  onChanged: (value) =>
                      unawaited(notifier.setMathFontStack(value)),
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          title: l10n.codeTypography,
          bottomSpacing: 0,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsControlRow(
                  title: Text(l10n.codeFontSize),
                  controlWidth: 560,
                  control: AppearancePreviewOptionGroup<CodeFontSizeMode>(
                    key: const Key('appearance_code_font_size_mode_options'),
                    value: settings.codeFontSizeMode,
                    options: [
                      for (final mode in CodeFontSizeMode.values)
                        AppearancePreviewOption(
                          key: Key(
                            'appearance_code_font_size_mode_${mode.name}_option',
                          ),
                          value: mode,
                          semanticLabel: _codeFontSizeModeLabel(l10n, mode),
                          width: 160,
                          minHeight: 82,
                          child: _CodeFontSizeModePreview(
                            label: _codeFontSizeModeLabel(l10n, mode),
                            settings: settings.copyWith(codeFontSizeMode: mode),
                          ),
                        ),
                    ],
                    onChanged: (mode) =>
                        unawaited(notifier.setCodeFontSizeMode(mode)),
                  ),
                ),
                if (settings.codeFontSizeMode == CodeFontSizeMode.custom)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SettingsSliderControl(
                      key: const Key('appearance_code_font_size_slider'),
                      value: settings.codeFontSize,
                      min: 11,
                      max: 24,
                      format: (value) => value.toStringAsFixed(0),
                      valueLabel:
                          '${l10n.codeFontSize} ${settings.codeFontSize.toStringAsFixed(0)}',
                      onChanged: (value) =>
                          unawaited(notifier.setCodeFontSize(value)),
                    ),
                  ),
                SliderTile(
                  key: const Key('appearance_code_line_height_slider'),
                  title: l10n.codeLineHeight,
                  value: settings.codeLineHeight,
                  min: 1.1,
                  max: 2.0,
                  format: (value) => value.toStringAsFixed(2),
                  onChanged: (value) =>
                      unawaited(notifier.setCodeLineHeight(value)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: _CodeAppearancePreview(settings: settings),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String appearanceFontSettingsSummary(
  AppLocalizations l10n,
  ReaderSettings settings,
) {
  final fontLabel = switch (settings.fontFamily) {
    ReaderFontFamily.system || ReaderFontFamily.custom => l10n.readerFontSystem,
    ReaderFontFamily.serif => l10n.readerFontSerif,
    ReaderFontFamily.sans => l10n.readerFontSans,
    ReaderFontFamily.mono => l10n.readerFontMono,
  };
  final sizeLabel = settings.codeFontSizeMode == CodeFontSizeMode.custom
      ? settings.codeFontSize.toStringAsFixed(0)
      : _codeFontSizeModeLabel(l10n, settings.codeFontSizeMode);
  return '$fontLabel · $sizeLabel';
}

String _codeFontSizeModeLabel(AppLocalizations l10n, CodeFontSizeMode mode) {
  return switch (mode) {
    CodeFontSizeMode.followReader => l10n.codeFontSizeFollowReader,
    CodeFontSizeMode.oneStepDown => l10n.codeFontSizeOneStepDown,
    CodeFontSizeMode.custom => l10n.custom,
  };
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
            '16: The quick brown fox jumps over the lazy dog\n雨落在窗前 Reading quietly 2026',
            maxLines: 2,
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

class _MathFontStackInlinePreview extends StatelessWidget {
  const _MathFontStackInlinePreview({required this.settings});

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
            '16: E = mc^2  |  \\int_0^1 x^2 dx',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.mathStyle.copyWith(
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

class _CodeFontSizeModePreview extends StatelessWidget {
  const _CodeFontSizeModePreview({required this.label, required this.settings});

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
            'value = 2026;',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: reader.codeStyle.copyWith(height: 1.2),
          ),
          const SizedBox(height: 8),
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
