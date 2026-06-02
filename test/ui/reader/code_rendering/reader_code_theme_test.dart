import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/reader/code_rendering/reader_code_rendering.dart';

void main() {
  test('default themes expose chrome search diff and token colors', () {
    final lightPalette = ReaderCodeTokenPalette.defaults(
      brightness: Brightness.light,
      errorColor: const Color(0xFFD1242F),
    );
    final darkPalette = ReaderCodeTokenPalette.defaults(
      brightness: Brightness.dark,
      errorColor: const Color(0xFFFF0000),
    );

    final lightTheme = ReaderCodeTheme(
      brightness: Brightness.light,
      surface: const Color(0xFFF6F8FA),
      headerSurface: const Color(0xFFEAEFf4),
      border: const Color(0xFFE0E0E0),
      gutterText: const Color(0xFF888888),
      gutterDivider: const Color(0xFFE0E0E0),
      searchBackground: const Color(0x33FFFF00),
      activeSearchBackground: const Color(0x55FFFF00),
      tokenColors: lightPalette,
    );
    final darkTheme = ReaderCodeTheme(
      brightness: Brightness.dark,
      surface: const Color(0xFF0D1117),
      headerSurface: const Color(0xFF161B22),
      border: const Color(0xFF30363D),
      gutterText: const Color(0xFF8B949E),
      gutterDivider: const Color(0xFF30363D),
      searchBackground: const Color(0x33FFFF00),
      activeSearchBackground: const Color(0x55FFFF00),
      tokenColors: darkPalette,
    );

    expect(lightTheme.surface, isNot(lightTheme.headerSurface));
    expect(lightTheme.gutterDivider, lightTheme.border);
    expect(lightTheme.colorFor(ReaderCodeTokenRole.keyword), isNotNull);
    expect(darkTheme.colorFor(ReaderCodeTokenRole.keyword), isNotNull);
    expect(
      lightTheme.colorFor(ReaderCodeTokenRole.keyword),
      isNot(darkTheme.colorFor(ReaderCodeTokenRole.keyword)),
    );
    expect(
      lightTheme.backgroundFor(ReaderCodeTokenRole.searchMatch),
      lightTheme.searchBackground,
    );
    expect(
      lightTheme.backgroundFor(ReaderCodeTokenRole.searchCurrent),
      lightTheme.activeSearchBackground,
    );
    expect(
      lightTheme.backgroundFor(ReaderCodeTokenRole.diffInserted),
      isNotNull,
    );
    expect(lightTheme.inlineColorPolicy, ReaderCodeInlineColorPolicy.preserve);
  });

  test(
    'token theme uses aggregate theme and preserves inline colors by default',
    () {
      final aggregateTheme = ReaderCodeTheme(
        brightness: Brightness.light,
        surface: const Color(0xFFF6F8FA),
        headerSurface: const Color(0xFFEAEFF4),
        border: const Color(0xFFE0E0E0),
        gutterText: const Color(0xFF888888),
        gutterDivider: const Color(0xFFE0E0E0),
        searchBackground: const Color(0x3300FF00),
        activeSearchBackground: const Color(0x5500FF00),
        tokenColors: ReaderCodeTokenPalette.defaults(
          brightness: Brightness.light,
          errorColor: const Color(0xFFD1242F),
        ),
      );
      final tokenTheme = ReaderCodeTokenTheme(theme: aggregateTheme);

      final keywordStyle = tokenTheme.styleFor(
        const ReaderCodeToken(
          text: 'import',
          role: ReaderCodeTokenRole.keyword,
          start: 0,
          end: 6,
        ),
      );
      final inlineStyle = tokenTheme.styleFor(
        const ReaderCodeToken(
          text: 'inline',
          role: ReaderCodeTokenRole.keyword,
          start: 0,
          end: 6,
          colorOverride: Color(0xFFFF0000),
        ),
      );
      final searchStyle = tokenTheme.styleFor(
        const ReaderCodeToken(
          text: 'target',
          role: ReaderCodeTokenRole.keyword,
          start: 0,
          end: 6,
          backgroundRole: ReaderCodeTokenRole.searchCurrent,
        ),
      );

      expect(
        keywordStyle?.color,
        aggregateTheme.colorFor(ReaderCodeTokenRole.keyword),
      );
      expect(inlineStyle?.color, const Color(0xFFFF0000));
      expect(
        searchStyle?.backgroundColor,
        aggregateTheme.activeSearchBackground,
      );
    },
  );
}
