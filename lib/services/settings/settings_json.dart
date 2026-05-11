T readEnumByNameOr<T extends Enum>(
  Iterable<T> values,
  Object? raw,
  T fallback, {
  bool trim = true,
}) {
  final name = raw is String ? (trim ? raw.trim() : raw) : '';
  if (name.isEmpty) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String? readOptionalString(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? null : value;
}

String readStringOrEmpty(Object? raw) => readOptionalString(raw) ?? '';

int? readOptionalInt(Object? raw) => raw is num ? raw.toInt() : null;

int readIntOr(Object? raw, int fallback) => readOptionalInt(raw) ?? fallback;

double readDoubleOr(Object? raw, double fallback) {
  return raw is num ? raw.toDouble() : fallback;
}

bool readBoolOr(Object? raw, {required bool fallback}) {
  return raw is bool ? raw : fallback;
}
