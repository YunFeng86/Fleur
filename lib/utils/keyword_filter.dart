/// Reserved keyword filter used by subscription/category/global filtering.
///
/// Syntax:
/// - Groups separated by `;` are OR'ed
/// - Within a group, tokens separated by `+` are AND'ed
///
/// Example: `dart+flutter;riverpod`
/// - matches if (contains "dart" AND "flutter") OR contains "riverpod".
class ReservedKeywordFilter {
  ReservedKeywordFilter._();

  static bool matches({
    required String pattern,
    required Iterable<String?> fields,
  }) {
    final p = pattern.trim();
    if (p.isEmpty) return true; // empty pattern => no filtering

    // Combine all fields into one haystack so tokens can match across fields.
    final haystack = fields
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n')
        .toLowerCase();
    if (haystack.isEmpty) return false;

    // OR groups by `;`
    final groups = p.split(';');
    var hasAnyValidGroup = false;

    for (final rawGroup in groups) {
      final g = rawGroup.trim();
      if (g.isEmpty) continue;

      // AND tokens by `+`
      final tokens = g
          .split('+')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList(growable: false);
      if (tokens.isEmpty) continue;

      hasAnyValidGroup = true;

      var ok = true;
      for (final token in tokens) {
        if (!haystack.contains(token)) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }

    // If pattern only contained separators/whitespace, treat it as empty.
    return !hasAnyValidGroup;
  }
}

