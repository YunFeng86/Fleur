import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reader_code_models.dart';

final class ReaderCodeScopeStyle {
  const ReaderCodeScopeStyle({
    this.role = ReaderCodeTokenRole.plain,
    this.colorOverride,
  });

  final ReaderCodeTokenRole role;
  final Color? colorOverride;

  ReaderCodeScopeStyle copyWith({
    ReaderCodeTokenRole? role,
    Color? colorOverride,
  }) {
    return ReaderCodeScopeStyle(
      role: role ?? this.role,
      colorOverride: colorOverride ?? this.colorOverride,
    );
  }
}

final class ReaderCodeScopeMapper {
  const ReaderCodeScopeMapper();

  ReaderCodeScopeStyle? styleFor({
    required Set<String> classes,
    String? inlineStyle,
  }) {
    final inlineColor = colorFromStyle(inlineStyle);
    final tokenStyle = roleForClasses(classes);
    if (inlineColor == null) return tokenStyle;
    return (tokenStyle ?? const ReaderCodeScopeStyle()).copyWith(
      colorOverride: inlineColor,
    );
  }

  ReaderCodeScopeStyle? roleForClasses(Set<String> classes) {
    return _prismRole(classes) ??
        _highlightJsRole(classes) ??
        _githubRole(classes);
  }

  static Color? colorFromStyle(String? style) {
    if (style == null || style.isEmpty) return null;
    final match = RegExp(
      r'(?:^|;)\s*color\s*:\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(style);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return _parseCssColor(raw);
  }

  static ReaderCodeScopeStyle? _prismRole(Set<String> classes) {
    if (!classes.contains('token')) return null;
    if (_containsAny(classes, const {
      'comment',
      'prolog',
      'cdata',
      'doctype',
    })) {
      return _role(ReaderCodeTokenRole.comment);
    }
    if (_containsAny(classes, const {'plain', 'plain-text'})) {
      return _role(ReaderCodeTokenRole.plain);
    }
    if (_containsAny(classes, const {
      'keyword',
      'module',
      'important',
      'atrule',
    })) {
      return _role(ReaderCodeTokenRole.keyword);
    }
    if (_containsAny(classes, const {
      'string',
      'char',
      'string-property',
      'attr-value',
      'url',
    })) {
      return _role(ReaderCodeTokenRole.string);
    }
    if (_containsAny(classes, const {'number', 'boolean'})) {
      return _role(ReaderCodeTokenRole.number);
    }
    if (_containsAny(classes, const {'constant', 'symbol'})) {
      return _role(ReaderCodeTokenRole.constant);
    }
    if (_containsAny(classes, const {'attr-name'})) {
      return _role(ReaderCodeTokenRole.attribute);
    }
    if (_containsAny(classes, const {'property', 'key', 'literal-property'})) {
      return _role(ReaderCodeTokenRole.property);
    }
    if (_containsAny(classes, const {'function'})) {
      return _role(ReaderCodeTokenRole.function);
    }
    if (_containsAny(classes, const {
      'class-name',
      'maybe-class-name',
      'known-class-name',
    })) {
      return _role(ReaderCodeTokenRole.type);
    }
    if (_containsAny(classes, const {'builtin'})) {
      return _role(ReaderCodeTokenRole.builtin);
    }
    if (_containsAny(classes, const {'tag', 'entity'})) {
      return _role(ReaderCodeTokenRole.tag);
    }
    if (_containsAny(classes, const {'variable', 'parameter', 'imports'})) {
      return _role(ReaderCodeTokenRole.variable);
    }
    if (_containsAny(classes, const {'regex'})) {
      return _role(ReaderCodeTokenRole.regex);
    }
    if (_containsAny(classes, const {'namespace'})) {
      return _role(ReaderCodeTokenRole.namespace);
    }
    if (_containsAny(classes, const {'inserted'})) {
      return _role(ReaderCodeTokenRole.diffInserted);
    }
    if (_containsAny(classes, const {'deleted'})) {
      return _role(ReaderCodeTokenRole.diffDeleted);
    }
    if (_containsAny(classes, const {'operator'})) {
      return _role(ReaderCodeTokenRole.operator);
    }
    if (_containsAny(classes, const {'punctuation'})) {
      return _role(ReaderCodeTokenRole.punctuation);
    }
    if (_containsAny(classes, const {'selector'})) {
      return _role(ReaderCodeTokenRole.tag);
    }
    return null;
  }

  static ReaderCodeScopeStyle? _highlightJsRole(Set<String> classes) {
    if (_containsAny(classes, const {'hljs-comment', 'hljs-quote'})) {
      return _role(ReaderCodeTokenRole.comment);
    }
    if (_containsAny(classes, const {
      'hljs-keyword',
      'hljs-doctag',
      'hljs-meta',
      'hljs-meta-keyword',
    })) {
      return _role(ReaderCodeTokenRole.keyword);
    }
    if (_containsAny(classes, const {
      'hljs-string',
      'hljs-code',
      'hljs-template-tag',
      'hljs-template-variable',
    })) {
      return _role(ReaderCodeTokenRole.string);
    }
    if (_containsAny(classes, const {'hljs-number'})) {
      return _role(ReaderCodeTokenRole.number);
    }
    if (_containsAny(classes, const {'hljs-literal'})) {
      return _role(ReaderCodeTokenRole.constant);
    }
    if (_containsAny(classes, const {
      'hljs-attr',
      'hljs-attribute',
      'hljs-property',
    })) {
      return _role(ReaderCodeTokenRole.attribute);
    }
    if (classes.contains('hljs-title.function') ||
        _containsPair(classes, 'hljs-title', 'function_') ||
        _containsAny(classes, const {'hljs-section'})) {
      return _role(ReaderCodeTokenRole.function);
    }
    if (classes.contains('hljs-title.class') ||
        _containsPair(classes, 'hljs-title', 'class_') ||
        _containsAny(classes, const {'hljs-type'})) {
      return _role(ReaderCodeTokenRole.type);
    }
    if (_containsAny(classes, const {'hljs-title'})) {
      return _role(ReaderCodeTokenRole.function);
    }
    if (_containsAny(classes, const {'hljs-built_in'})) {
      return _role(ReaderCodeTokenRole.builtin);
    }
    if (_containsAny(classes, const {'hljs-name', 'hljs-tag'})) {
      return _role(ReaderCodeTokenRole.tag);
    }
    if (_containsAny(classes, const {
      'hljs-selector-tag',
      'hljs-selector-id',
      'hljs-selector-class',
      'hljs-selector-attr',
      'hljs-selector-pseudo',
    })) {
      return _role(ReaderCodeTokenRole.tag);
    }
    if (_containsAny(classes, const {
      'hljs-variable',
      'hljs-variable.language',
      'hljs-params',
      'hljs-symbol',
      'hljs-bullet',
    })) {
      return _role(ReaderCodeTokenRole.variable);
    }
    if (_containsAny(classes, const {'hljs-regexp'})) {
      return _role(ReaderCodeTokenRole.regex);
    }
    if (_containsAny(classes, const {'hljs-addition'})) {
      return _role(ReaderCodeTokenRole.diffInserted);
    }
    if (_containsAny(classes, const {'hljs-deletion'})) {
      return _role(ReaderCodeTokenRole.diffDeleted);
    }
    if (_containsAny(classes, const {'hljs-operator'})) {
      return _role(ReaderCodeTokenRole.operator);
    }
    if (_containsAny(classes, const {'hljs-punctuation'})) {
      return _role(ReaderCodeTokenRole.punctuation);
    }
    if (_containsAny(classes, const {'hljs-meta.prompt'})) {
      return _role(ReaderCodeTokenRole.builtin);
    }
    return null;
  }

  static ReaderCodeScopeStyle? _githubRole(Set<String> classes) {
    if (_containsAny(classes, const {'pl-c', 'pl-c1-comment'})) {
      return _role(ReaderCodeTokenRole.comment);
    }
    if (_containsAny(classes, const {'pl-k', 'pl-kos'})) {
      return _role(ReaderCodeTokenRole.keyword);
    }
    if (_containsAny(classes, const {
      'pl-s',
      'pl-pds',
      'pl-s1',
      'pl-sr',
      'pl-cce',
    })) {
      return _role(ReaderCodeTokenRole.string);
    }
    if (_containsAny(classes, const {'pl-c1'})) {
      return _role(ReaderCodeTokenRole.constant);
    }
    if (_containsAny(classes, const {'pl-en'})) {
      return _role(ReaderCodeTokenRole.function);
    }
    if (_containsAny(classes, const {'pl-ent'})) {
      return _role(ReaderCodeTokenRole.tag);
    }
    if (_containsAny(classes, const {'pl-e', 'pl-v'})) {
      return _role(ReaderCodeTokenRole.variable);
    }
    if (_containsAny(classes, const {'pl-smi', 'pl-smi1'})) {
      return _role(ReaderCodeTokenRole.type);
    }
    if (_containsAny(classes, const {'pl-corl'})) {
      return _role(ReaderCodeTokenRole.string);
    }
    return null;
  }

  static ReaderCodeScopeStyle _role(ReaderCodeTokenRole role) {
    return ReaderCodeScopeStyle(role: role);
  }

  static bool _containsAny(Set<String> classes, Set<String> candidates) {
    for (final candidate in candidates) {
      if (classes.contains(candidate)) return true;
    }
    return false;
  }

  static bool _containsPair(Set<String> classes, String a, String b) {
    return classes.contains(a) && classes.contains(b);
  }

  static Color? _parseCssColor(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.startsWith('#')) return _parseHexColor(value);
    if (value.startsWith('rgb(') || value.startsWith('rgba(')) {
      return _parseRgbColor(value);
    }
    return null;
  }

  static Color? _parseHexColor(String value) {
    final hex = value.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((c) => '$c$c').join();
      return _parseHexColor('#$expanded');
    }
    if (hex.length != 6) return null;
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  static Color? _parseRgbColor(String value) {
    final start = value.indexOf('(');
    final end = value.lastIndexOf(')');
    if (start < 0 || end <= start) return null;
    final parts = value
        .substring(start + 1, end)
        .split(',')
        .map((part) => part.trim())
        .toList(growable: false);
    if (parts.length < 3) return null;
    final r = _parseRgbComponent(parts[0]);
    final g = _parseRgbComponent(parts[1]);
    final b = _parseRgbComponent(parts[2]);
    if (r == null || g == null || b == null) return null;
    final alpha = parts.length >= 4 ? _parseAlpha(parts[3]) : 255;
    if (alpha == null) return null;
    return Color.fromARGB(alpha, r, g, b);
  }

  static int? _parseRgbComponent(String value) {
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }
    final parsed = int.tryParse(value);
    return parsed == null ? null : math.max(0, math.min(255, parsed));
  }

  static int? _parseAlpha(String value) {
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }
    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    return (parsed.clamp(0, 1) * 255).round();
  }
}
