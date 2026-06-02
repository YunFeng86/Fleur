import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';
import 'reader_code_models.dart';

enum ReaderCodeInlineColorPolicy { preserve, ignore }

final class ReaderCodeTheme {
  const ReaderCodeTheme({
    required this.brightness,
    required this.surface,
    required this.headerSurface,
    required this.border,
    required this.gutterText,
    required this.gutterDivider,
    required this.searchBackground,
    required this.activeSearchBackground,
    required this.tokenColors,
    this.inlineColorPolicy = ReaderCodeInlineColorPolicy.preserve,
  });

  factory ReaderCodeTheme.resolve(BuildContext context) {
    final theme = Theme.of(context);
    return ReaderCodeTheme.fromTheme(theme);
  }

  factory ReaderCodeTheme.fromTheme(ThemeData theme) {
    final reader = theme.fleurReader;
    final surface = reader.codeBlockSurface;
    final headerSurface = Color.alphaBlend(
      theme.colorScheme.onSurface.withAlpha(
        theme.brightness == Brightness.dark ? 18 : 8,
      ),
      surface,
    );
    return ReaderCodeTheme(
      brightness: theme.brightness,
      surface: surface,
      headerSurface: headerSurface,
      border: theme.fleurSurface.subtleDivider,
      gutterText: theme.colorScheme.onSurfaceVariant.withAlpha(150),
      gutterDivider: theme.fleurSurface.subtleDivider,
      searchBackground: reader.bannerSurface.withValues(alpha: 0.8),
      activeSearchBackground: theme.fleurState.selectionTint.withValues(
        alpha: 0.95,
      ),
      tokenColors: ReaderCodeTokenPalette.defaults(
        brightness: theme.brightness,
        errorColor: theme.colorScheme.error,
      ),
    );
  }

  final Brightness brightness;
  final Color surface;
  final Color headerSurface;
  final Color border;
  final Color gutterText;
  final Color gutterDivider;
  final Color searchBackground;
  final Color activeSearchBackground;
  final ReaderCodeTokenPalette tokenColors;
  final ReaderCodeInlineColorPolicy inlineColorPolicy;

  Color? colorFor(ReaderCodeTokenRole role) => tokenColors.colorFor(role);

  Color? backgroundFor(ReaderCodeTokenRole role) {
    return switch (role) {
      ReaderCodeTokenRole.searchMatch => searchBackground,
      ReaderCodeTokenRole.searchCurrent => activeSearchBackground,
      _ => tokenColors.backgroundFor(role),
    };
  }
}

final class ReaderCodeTokenPalette {
  const ReaderCodeTokenPalette({
    required this.brightness,
    required this.errorColor,
  });

  factory ReaderCodeTokenPalette.defaults({
    required Brightness brightness,
    required Color errorColor,
  }) {
    return ReaderCodeTokenPalette(
      brightness: brightness,
      errorColor: errorColor,
    );
  }

  final Brightness brightness;
  final Color errorColor;

  Color? colorFor(ReaderCodeTokenRole role) {
    final dark = brightness == Brightness.dark;
    return switch (role) {
      ReaderCodeTokenRole.keyword =>
        dark ? const Color(0xFFFF7B72) : const Color(0xFF00009F),
      ReaderCodeTokenRole.string || ReaderCodeTokenRole.regex =>
        dark ? const Color(0xFFA5D6FF) : const Color(0xFFE3116C),
      ReaderCodeTokenRole.number || ReaderCodeTokenRole.constant =>
        dark ? const Color(0xFF79C0FF) : const Color(0xFF36ACAA),
      ReaderCodeTokenRole.comment =>
        dark ? const Color(0xFF8B949E) : const Color(0xFF6A737D),
      ReaderCodeTokenRole.function =>
        dark ? const Color(0xFFD2A8FF) : const Color(0xFFD73A49),
      ReaderCodeTokenRole.type || ReaderCodeTokenRole.builtin =>
        dark ? const Color(0xFFFFA657) : const Color(0xFFD73A49),
      ReaderCodeTokenRole.property || ReaderCodeTokenRole.attribute =>
        dark ? const Color(0xFF79C0FF) : const Color(0xFF36ACAA),
      ReaderCodeTokenRole.tag || ReaderCodeTokenRole.namespace =>
        dark ? const Color(0xFF7EE787) : const Color(0xFF00009F),
      ReaderCodeTokenRole.variable =>
        dark ? const Color(0xFFC9D1D9) : const Color(0xFF393A34),
      ReaderCodeTokenRole.operator || ReaderCodeTokenRole.punctuation =>
        dark ? const Color(0xFFC9D1D9) : const Color(0xFF393A34),
      ReaderCodeTokenRole.diffInserted =>
        dark ? const Color(0xFF7EE787) : const Color(0xFF116329),
      ReaderCodeTokenRole.diffDeleted =>
        dark ? const Color(0xFFFF7B72) : errorColor,
      _ => null,
    };
  }

  Color? backgroundFor(ReaderCodeTokenRole role) {
    final dark = brightness == Brightness.dark;
    return switch (role) {
      ReaderCodeTokenRole.diffInserted => colorFor(
        ReaderCodeTokenRole.diffInserted,
      )?.withAlpha(dark ? 44 : 30),
      ReaderCodeTokenRole.diffDeleted => colorFor(
        ReaderCodeTokenRole.diffDeleted,
      )?.withAlpha(dark ? 42 : 28),
      _ => null,
    };
  }
}
