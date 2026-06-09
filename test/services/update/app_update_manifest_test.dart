import 'dart:ui';

import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses manifest and resolves localized notes', () {
    final manifest = AppUpdateManifest.fromJson({
      'schemaVersion': 1,
      'channel': 'stable',
      'version': '0.1.5',
      'tag': 'v0.1.5',
      'publishedAt': '2026-06-09T00:00:00Z',
      'releaseUrl': 'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
      'notes': {'en': '- Fixed', 'zh': '- 修复'},
      'assets': {
        'macos': {
          'url':
              'https://github.com/ZeyrMe/Fleur/releases/download/v0.1.5/fleur-macos-0.1.5.dmg',
          'sha256': 'abc',
        },
      },
    });

    expect(manifest.channel, AppUpdateChannel.stable);
    expect(manifest.notesForLocale(const Locale('zh')), '- 修复');
    expect(manifest.notesForLocale(const Locale('fr')), '- Fixed');
    expect(manifest.assets['macos']?.sha256, 'abc');
  });

  test('requires English notes as final fallback', () {
    expect(
      () => AppUpdateManifest.fromJson({
        'schemaVersion': 1,
        'channel': 'stable',
        'version': '0.1.5',
        'tag': 'v0.1.5',
        'releaseUrl': 'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
        'notes': {'zh': '- 修复'},
      }),
      throwsFormatException,
    );
  });

  test('rejects invalid release url', () {
    expect(
      () => AppUpdateManifest.fromJson({
        'schemaVersion': 1,
        'channel': 'stable',
        'version': '0.1.5',
        'tag': 'v0.1.5',
        'releaseUrl': 'not a url',
        'notes': {'en': '- Fixed'},
      }),
      throwsFormatException,
    );
  });
}
