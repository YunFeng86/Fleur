DateTime? tryParseFeedDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  // Atom is usually ISO-8601.
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toUtc();

  // RSS is often RFC822/RFC1123-ish: "Tue, 06 Aug 2024 10:00:00 +0000".
  final rfc = _tryParseRfc822Like(s);
  if (rfc != null) return rfc;

  return null;
}

DateTime? _tryParseRfc822Like(String s) {
  final months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  final re = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s+(.+)$',
  );
  final m = re.firstMatch(s);
  if (m == null) return null;

  final day = int.tryParse(m.group(1)!) ?? 0;
  final monKey = m.group(2)!.toLowerCase();
  final month = months[monKey] ?? 0;
  final year = int.tryParse(m.group(3)!) ?? 0;
  final hour = int.tryParse(m.group(4)!) ?? 0;
  final minute = int.tryParse(m.group(5)!) ?? 0;
  final second = int.tryParse(m.group(6) ?? '0') ?? 0;
  final tz = m.group(7)!.trim();

  if (day <= 0 || month <= 0 || year <= 0) return null;

  final baseUtc = DateTime.utc(year, month, day, hour, minute, second);

  final offset = _parseTzOffsetMinutes(tz);
  if (offset == null) return baseUtc; // fall back to treating it as UTC

  return baseUtc.subtract(Duration(minutes: offset));
}

int? _parseTzOffsetMinutes(String tz) {
  final upper = tz.toUpperCase();
  if (upper == 'UTC' || upper == 'UT' || upper == 'GMT' || upper == 'Z') {
    return 0;
  }

  // +0800 / -0430
  final m = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(upper);
  if (m == null) return null;
  final sign = m.group(1) == '-' ? -1 : 1;
  final hh = int.tryParse(m.group(2)!) ?? 0;
  final mm = int.tryParse(m.group(3)!) ?? 0;
  return sign * (hh * 60 + mm);
}

