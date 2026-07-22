import 'package:flutter/material.dart';

import 'reader_code_models.dart';
import 'reader_code_theme.dart';

final class ReaderCodeTokenTheme {
  const ReaderCodeTokenTheme({required this.theme});

  final ReaderCodeTheme theme;

  TextStyle? styleFor(ReaderCodeToken token) {
    final color =
        switch (theme.inlineColorPolicy) {
          ReaderCodeInlineColorPolicy.preserve => token.colorOverride,
          ReaderCodeInlineColorPolicy.ignore => null,
        } ??
        colorFor(token.role);
    final background = backgroundFor(token.backgroundRole ?? token.role);
    if (color == null && background == null) return null;
    return TextStyle(color: color, backgroundColor: background);
  }

  Color? colorFor(ReaderCodeTokenRole role) {
    return theme.colorFor(role);
  }

  Color? backgroundFor(ReaderCodeTokenRole role) {
    return theme.backgroundFor(role);
  }
}
