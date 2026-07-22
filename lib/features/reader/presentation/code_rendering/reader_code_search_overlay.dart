import 'package:flutter/material.dart';

import 'reader_code_models.dart';

TextSpan applyReaderCodeSearchRanges(
  TextSpan span, {
  required List<ReaderCodeSearchRange> searchRanges,
  required String? currentAnchorId,
  required Color activeBackground,
  required Color background,
}) {
  if (searchRanges.isEmpty) return span;
  final ranges = [...searchRanges]..sort((a, b) => a.start.compareTo(b.start));
  var offset = 0;

  TextSpan visit(TextSpan node) {
    final children = <InlineSpan>[];
    final text = node.text;
    if (text != null && text.isNotEmpty) {
      children.addAll(
        _splitReaderCodeSearchText(
          text,
          node.style,
          offset,
          ranges: ranges,
          currentAnchorId: currentAnchorId,
          activeBackground: activeBackground,
          background: background,
        ),
      );
      offset += text.length;
    }
    for (final child in node.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) {
        children.add(visit(child));
      } else {
        children.add(child);
      }
    }
    return TextSpan(
      style: node.style,
      children: children.isEmpty ? null : children,
    );
  }

  return visit(span);
}

List<TextSpan> _splitReaderCodeSearchText(
  String text,
  TextStyle? style,
  int globalStart, {
  required List<ReaderCodeSearchRange> ranges,
  required String? currentAnchorId,
  required Color activeBackground,
  required Color background,
}) {
  final boundaries = <int>{0, text.length};
  final globalEnd = globalStart + text.length;
  for (final range in ranges) {
    if (range.end <= globalStart) continue;
    if (range.start >= globalEnd) break;
    boundaries.add((range.start - globalStart).clamp(0, text.length));
    boundaries.add((range.end - globalStart).clamp(0, text.length));
  }
  final sorted = boundaries.toList()..sort();
  final spans = <TextSpan>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final start = sorted[i];
    final end = sorted[i + 1];
    if (start == end) continue;
    final range = _readerCodeSearchRangeAt(
      ranges,
      globalStart + start,
      globalStart + end,
    );
    final bg = range == null
        ? null
        : range.anchorId == currentAnchorId
        ? activeBackground
        : background;
    spans.add(
      TextSpan(
        text: text.substring(start, end),
        style: bg == null
            ? style
            : (style ?? const TextStyle()).copyWith(backgroundColor: bg),
      ),
    );
  }
  return spans;
}

ReaderCodeSearchRange? _readerCodeSearchRangeAt(
  List<ReaderCodeSearchRange> ranges,
  int start,
  int end,
) {
  for (final range in ranges) {
    if (range.end <= start) continue;
    if (range.start >= end) return null;
    return range;
  }
  return null;
}
