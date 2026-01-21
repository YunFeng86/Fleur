import 'package:flutter/material.dart';

const List<String> kTagColorPalette = [
  '#6750A4', // M3 primary
  '#4F378B', // M3 primary variant
  '#625B71', // M3 secondary
  '#7D5260', // M3 tertiary
  '#006A6A', // teal
  '#005FAF', // blue
  '#386A20', // green
  '#5D5F00', // lime
  '#775A00', // amber
  '#984061', // pink
  '#B3261E', // error
  '#00639A', // blue variant
];

String? normalizeTagColor(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return '#${hex.toUpperCase()}';
}

Color? tagColorFromHex(String? raw) {
  final normalized = normalizeTagColor(raw);
  if (normalized == null) return null;
  final hex = normalized.substring(1);
  final value = int.parse(hex, radix: 16);
  return Color(0xFF000000 | value);
}

String pickTagColorForName(String name) {
  if (kTagColorPalette.isEmpty) return '#6750A4';
  final trimmed = name.trim().toLowerCase();
  if (trimmed.isEmpty) return kTagColorPalette.first;
  var hash = 0;
  for (final code in trimmed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  final idx = hash % kTagColorPalette.length;
  return kTagColorPalette[idx];
}

String ensureTagColor(String name, String? raw) {
  return normalizeTagColor(raw) ?? pickTagColorForName(name);
}

Color resolveTagColor(String name, String? raw) {
  return tagColorFromHex(raw) ??
      tagColorFromHex(pickTagColorForName(name))!;
}
