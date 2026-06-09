import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final arbFiles =
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, Object?> readArb(File file) =>
      (jsonDecode(file.readAsStringSync()) as Map<String, Object?>);

  Set<String> messageKeys(Map<String, Object?> data) =>
      data.keys.where((k) => !k.startsWith('@')).toSet();

  Set<String> metadataKeys(Map<String, Object?> data) =>
      data.keys.where((k) => k.startsWith('@')).toSet();

  Set<String> placeholderNamesFromMetadata(
    Map<String, Object?> data,
    String key,
  ) {
    final metadata = data['@$key'];
    if (metadata is! Map<String, Object?>) return const {};
    final placeholders = metadata['placeholders'];
    if (placeholders is! Map<String, Object?>) return const {};
    return placeholders.keys.toSet();
  }

  Set<String> placeholderNamesFromMessage(Object? value) {
    if (value is! String) return const {};
    return RegExp(
      r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
    ).allMatches(value).map((m) => m.group(1)!).toSet();
  }

  ({String variable, String type})? icuShape(Object? value) {
    if (value is! String) return null;
    final match = RegExp(
      r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(plural|select)\b',
    ).firstMatch(value);
    if (match == null) return null;
    return (variable: match.group(1)!, type: match.group(2)!);
  }

  test('all ARB files match template keys, placeholders, and ICU shape', () {
    final template = readArb(File('lib/l10n/app_en.arb'));
    final templateMessageKeys = messageKeys(template);
    final templateMetadataKeys = metadataKeys(template);

    for (final file in arbFiles) {
      final data = readArb(file);
      expect(messageKeys(data), templateMessageKeys, reason: file.path);
      expect(metadataKeys(data), templateMetadataKeys, reason: file.path);

      for (final key in templateMessageKeys) {
        expect(
          placeholderNamesFromMetadata(data, key),
          placeholderNamesFromMetadata(template, key),
          reason: '${file.path}: @$key placeholders',
        );
        expect(
          placeholderNamesFromMessage(data[key]),
          placeholderNamesFromMessage(template[key]),
          reason: '${file.path}: $key message placeholders',
        );

        final expectedIcu = icuShape(template[key]);
        if (expectedIcu != null) {
          expect(
            icuShape(data[key]),
            expectedIcu,
            reason: '${file.path}: $key',
          );
        }
      }
    }
  });

  test('zh and zh_Hans have identical message values', () {
    final zh = readArb(File('lib/l10n/app_zh.arb'));
    final zhHans = readArb(File('lib/l10n/app_zh_Hans.arb'));

    for (final key in messageKeys(zh)) {
      expect(zhHans[key], zh[key], reason: key);
    }
  });
}
