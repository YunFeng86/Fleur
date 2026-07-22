import 'reader_code_models.dart';

List<ReaderCodeToken> applyReaderCodeSearchTokenOverlay(
  List<ReaderCodeToken> tokens, {
  required List<ReaderCodeSearchRange> searchRanges,
  required String? currentAnchorId,
}) {
  if (searchRanges.isEmpty || tokens.isEmpty) return tokens;
  final ranges = [...searchRanges]..sort((a, b) => a.start.compareTo(b.start));
  final result = <ReaderCodeToken>[];

  for (final token in tokens) {
    final boundaries = <int>{token.start, token.end};
    for (final range in ranges) {
      if (range.end <= token.start) continue;
      if (range.start >= token.end) break;
      boundaries.add(range.start.clamp(token.start, token.end));
      boundaries.add(range.end.clamp(token.start, token.end));
    }
    final sorted = boundaries.toList()..sort();
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start == end) continue;
      final range = _rangeAt(ranges, start, end);
      final backgroundRole = range == null
          ? token.backgroundRole
          : range.anchorId == currentAnchorId
          ? ReaderCodeTokenRole.searchCurrent
          : ReaderCodeTokenRole.searchMatch;
      result.add(
        token.copyWith(
          text: token.text.substring(start - token.start, end - token.start),
          start: start,
          end: end,
          backgroundRole: backgroundRole,
        ),
      );
    }
  }

  return result;
}

ReaderCodeSearchRange? _rangeAt(
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
