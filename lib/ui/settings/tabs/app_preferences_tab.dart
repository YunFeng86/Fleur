import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/settings/reader_settings.dart';
import '../../../theme/fleur_icons.dart';
import '../../../theme/seed_color_presets.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/platform.dart';
import '../widgets/section_header.dart';
import '../widgets/slider_tile.dart';

class AppPreferencesTab extends ConsumerWidget {
  const AppPreferencesTab({super.key, this.showPageTitle = true});

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

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final currentBrightness = Theme.of(context).brightness;

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
          SectionHeader(title: l10n.appPreferences),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.language,
          child: SettingsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: appSettings.localeTag,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.systemLanguage),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'en',
                    child: Text(l10n.english),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'zh',
                    child: Text(l10n.chineseSimplified),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'zh-Hant',
                    child: Text(l10n.chineseTraditional),
                  ),
                ],
                onChanged: (v) {
                  unawaited(() async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setLocaleTag(v);
                    if (!context.mounted) return;
                    if (!isMacOS) return;
                    context.showSnack(l10n.macosMenuLanguageRestartHint);
                  }());
                },
              ),
            ),
          ),
        ),
        SettingsSection(
          title: l10n.theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.themeMode, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<ThemeMode>(
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
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SettingsCard(
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
                        IconButton(
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
                          icon: const Icon(FleurIcons.reset),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (isAndroid)
                          Tooltip(
                            message: l10n.dynamicColorSubtitle,
                            child: _ThemeColorCard(
                              selected: appSettings.useDynamicColor,
                              scheme: Theme.of(context).colorScheme,
                              semanticLabel: l10n.dynamicColor,
                              trailingIcon: const Icon(
                                FleurIcons.colorPicker,
                                size: 18,
                              ),
                              onTap: () {
                                unawaited(
                                  ref
                                      .read(appSettingsProvider.notifier)
                                      .setUseDynamicColor(true),
                                );
                              },
                            ),
                          ),
                        for (final p in SeedColorPreset.values)
                          Tooltip(
                            message: seedPresetLabel(p),
                            child: _ThemeColorCard(
                              selected:
                                  !appSettings.useDynamicColor &&
                                  appSettings.seedColorPreset == p,
                              scheme: ColorScheme.fromSeed(
                                seedColor: p.seedColor,
                                brightness: currentBrightness,
                              ),
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
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
          title: l10n.readerSettings,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                SettingsSwitchTile(
                  title: Text(l10n.autoMarkRead),
                  value: appSettings.autoMarkRead,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).setAutoMarkRead(v),
                ),
                SliderTile(
                  title: l10n.fontSize,
                  value: readerSettings.fontSize,
                  min: 12,
                  max: 28,
                  format: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(fontSize: v)),
                ),
                SliderTile(
                  title: l10n.lineHeight,
                  value: readerSettings.lineHeight,
                  min: 1.1,
                  max: 2.2,
                  format: (v) => v.toStringAsFixed(1),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(lineHeight: v)),
                ),
                SliderTile(
                  title: l10n.horizontalPadding,
                  value: readerSettings.horizontalPadding,
                  min: 8,
                  max: 32,
                  format: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(horizontalPadding: v)),
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          title: l10n.storage,
          bottomSpacing: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.clearImageCacheSubtitle,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(cacheManagerProvider).emptyCache();
                        await ref.read(imageMetaStoreProvider).clear();
                        if (!context.mounted) return;
                        context.showSnack(l10n.cacheCleared);
                      },
                      child: Text(l10n.clearImageCache),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cleanupReadArticles,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 240),
                          child: DropdownButton<int?>(
                            value: appSettings.cleanupReadOlderThanDays,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(l10n.off),
                              ),
                              for (final d in const [7, 30, 90, 180])
                                DropdownMenuItem<int?>(
                                  value: d,
                                  child: Text(l10n.days(d)),
                                ),
                            ],
                            onChanged: (v) => ref
                                .read(appSettingsProvider.notifier)
                                .setCleanupReadOlderThanDays(v),
                          ),
                        ),
                        OutlinedButton(
                          onPressed:
                              appSettings.cleanupReadOlderThanDays == null
                              ? null
                              : () async {
                                  final days =
                                      appSettings.cleanupReadOlderThanDays!;
                                  final cutoff = DateTime.now()
                                      .toUtc()
                                      .subtract(Duration(days: days));
                                  final n = await ref
                                      .read(articleRepositoryProvider)
                                      .deleteReadUnstarredOlderThan(cutoff);
                                  if (!context.mounted) return;
                                  context.showSnack(l10n.cleanedArticles(n));
                                },
                          child: Text(l10n.cleanupNow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeColorCard extends StatelessWidget {
  const _ThemeColorCard({
    required this.selected,
    required this.scheme,
    required this.onTap,
    this.trailingIcon,
    this.semanticLabel,
  });

  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final Widget? trailingIcon;
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
                if (trailingIcon != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconTheme(
                      data: IconThemeData(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: trailingIcon!,
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

    // Left half: primary
    paint.color = scheme.primary;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), paint);

    // Right-top: secondary
    paint.color = scheme.secondary;
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height / 2),
      paint,
    );

    // Right-bottom: tertiary
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

    // Circle outline for contrast.
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
