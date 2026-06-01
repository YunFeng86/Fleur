import 'package:flutter/material.dart';

import 'reader_code_models.dart';

final class ReaderCodeTokenTheme {
  const ReaderCodeTokenTheme({
    required this.brightness,
    required this.errorColor,
    this.searchBackground,
    this.activeSearchBackground,
  });

  final Brightness brightness;
  final Color errorColor;
  final Color? searchBackground;
  final Color? activeSearchBackground;

  TextStyle? styleFor(ReaderCodeToken token) {
    final color = token.colorOverride ?? colorFor(token.role);
    final background = backgroundFor(token.backgroundRole ?? token.role);
    if (color == null && background == null) return null;
    return TextStyle(color: color, backgroundColor: background);
  }

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
      ReaderCodeTokenRole.searchMatch => searchBackground,
      ReaderCodeTokenRole.searchCurrent => activeSearchBackground,
      _ => null,
    };
  }
}
