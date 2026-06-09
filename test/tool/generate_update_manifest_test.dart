import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/generate_update_manifest.dart';

void main() {
  tearDown(() {
    exitCode = 0;
  });

  test('extracts user-facing notes and excludes internal section', () {
    final notes = parseReleaseNotes(
      tag: 'v0.1.5',
      markdown: '''
# Fleur v0.1.5

<!-- update-notes:en -->
- Fixed sync.
<!-- /update-notes:en -->

<!-- update-notes:zh -->
- 修复同步。
<!-- /update-notes:zh -->

## Internal
- Do not show this.
''',
    );

    expect(notes.notes['en'], '- Fixed sync.');
    expect(notes.notes['zh'], '- 修复同步。');
    expect(notes.notes.values.join('\n'), isNot(contains('Do not show this')));
  });

  test('requires English notes', () {
    expect(
      () => parseReleaseNotes(
        tag: 'v0.1.5',
        markdown: '''
<!-- update-notes:zh -->
- 修复同步。
<!-- /update-notes:zh -->
''',
      ),
      throwsStateError,
    );
  });

  test('maps prerelease tags to beta channel', () {
    expect(channelForTag('v0.1.5'), 'stable');
    expect(channelForTag('v0.1.5-beta.1'), 'beta');
    expect(channelForTag('v0.1.5-rc.1'), 'beta');
  });

  test('builds v1 manifest', () {
    final manifest = buildManifest(
      channel: 'stable',
      version: '0.1.5',
      tag: 'v0.1.5',
      publishedAt: '2026-06-09T00:00:00Z',
      releaseUrl: 'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
      notes: const {'en': '- Fixed'},
      assets: const [
        ReleaseAsset(
          key: 'macos',
          filename: 'fleur-macos-0.1.5.dmg',
          url:
              'https://github.com/ZeyrMe/Fleur/releases/download/v0.1.5/fleur-macos-0.1.5.dmg',
          sha256: 'abc',
        ),
      ],
    );

    expect(manifest['schemaVersion'], 1);
    expect(manifest['channel'], 'stable');
    expect((manifest['assets']! as Map<String, Object?>), contains('macos'));
  });
}
