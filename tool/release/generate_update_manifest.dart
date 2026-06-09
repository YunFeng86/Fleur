import 'dart:convert';
import 'dart:io';

const updateSchemaVersion = 1;
const supportedChannels = {'stable', 'beta'};

Future<void> main(List<String> arguments) async {
  final options = CliOptions.parse(arguments);
  await generateUpdateManifest(options);
}

Future<void> generateUpdateManifest(CliOptions options) async {
  final tag = options.required('tag');
  final repository = options.required('repository');
  final releaseFilesDir = Directory(options.required('release-files'));
  final outputDir = Directory(options.required('output'));
  final releaseBodyPath = options['release-body'];
  final generatedNotesPath = options['generated-notes'];
  final pagesBaseUrl = options['pages-base-url'];
  final publishedAt =
      options['published-at'] ?? DateTime.now().toUtc().toIso8601String();

  final releaseNotesFile = File('docs/releases/$tag.md');
  if (!releaseNotesFile.existsSync()) {
    fail('Missing release notes file: ${releaseNotesFile.path}');
  }

  final releaseNotes = parseReleaseNotes(
    tag: tag,
    markdown: releaseNotesFile.readAsStringSync(),
  );
  final channel = channelForTag(tag);
  final version = versionFromTag(tag);
  final releaseUrl = 'https://github.com/$repository/releases/tag/$tag';

  if (!releaseFilesDir.existsSync()) {
    fail('Missing release files directory: ${releaseFilesDir.path}');
  }

  await outputDir.create(recursive: true);
  if (pagesBaseUrl != null && pagesBaseUrl.trim().isNotEmpty) {
    await restoreExistingMetadata(
      outputDir: outputDir,
      pagesBaseUrl: pagesBaseUrl.trim(),
    );
  }

  final assets = await collectReleaseAssets(
    releaseFilesDir: releaseFilesDir,
    repository: repository,
    tag: tag,
  );
  await writeChecksumFile(releaseFilesDir, assets);

  final manifest = buildManifest(
    channel: channel,
    version: version,
    tag: tag,
    publishedAt: publishedAt,
    releaseUrl: releaseUrl,
    notes: releaseNotes.notes,
    assets: assets,
  );

  final channelDir = Directory('${outputDir.path}/updates/$channel');
  await channelDir.create(recursive: true);
  writeJson(File('${channelDir.path}/latest.json'), manifest);
  writeJson(File('${channelDir.path}/$tag.json'), manifest);
  updateIndex(outputDir: outputDir, channel: channel, tag: tag);

  if (releaseBodyPath != null) {
    final generatedNotes = generatedNotesPath == null
        ? null
        : File(generatedNotesPath).existsSync()
        ? File(generatedNotesPath).readAsStringSync().trim()
        : null;
    File(releaseBodyPath).writeAsStringSync(
      buildReleaseBody(
        tag: tag,
        releaseNotes: releaseNotes,
        assets: assets,
        generatedNotes: generatedNotes,
      ),
    );
  }
}

ReleaseNotes parseReleaseNotes({
  required String tag,
  required String markdown,
}) {
  final matches = RegExp(
    r'<!--\s*update-notes:([A-Za-z0-9_-]+)\s*-->([\s\S]*?)<!--\s*/update-notes:\1\s*-->',
    multiLine: true,
  ).allMatches(markdown);

  final notes = <String, String>{};
  for (final match in matches) {
    final locale = match.group(1)!.trim();
    final body = match.group(2)!.trim();
    if (body.isNotEmpty) notes[locale] = body;
  }

  if ((notes['en'] ?? '').trim().isEmpty) {
    fail('Release notes for $tag must include non-empty update-notes:en');
  }

  return ReleaseNotes(tag: tag, notes: notes);
}

String channelForTag(String tag) {
  final prereleasePattern = RegExp(r'-(alpha|beta|rc)(\.|-|$)');
  return prereleasePattern.hasMatch(tag) ? 'beta' : 'stable';
}

String versionFromTag(String tag) {
  if (!tag.startsWith('v') || tag.length < 2) {
    fail('Release tag must start with v: $tag');
  }
  return tag.substring(1);
}

Map<String, Object?> buildManifest({
  required String channel,
  required String version,
  required String tag,
  required String publishedAt,
  required String releaseUrl,
  required Map<String, String> notes,
  required List<ReleaseAsset> assets,
}) {
  if (!supportedChannels.contains(channel)) {
    fail('Unsupported release channel: $channel');
  }
  return {
    'schemaVersion': updateSchemaVersion,
    'channel': channel,
    'version': version,
    'tag': tag,
    'publishedAt': publishedAt,
    'releaseUrl': releaseUrl,
    'notes': notes,
    'assets': {
      for (final asset in assets)
        asset.key: {'url': asset.url, 'sha256': asset.sha256},
    },
  };
}

Future<List<ReleaseAsset>> collectReleaseAssets({
  required Directory releaseFilesDir,
  required String repository,
  required String tag,
}) async {
  final files =
      releaseFilesDir
          .listSync()
          .whereType<File>()
          .where((file) => !file.path.endsWith('/SHA256SUMS.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final assets = <ReleaseAsset>[];
  for (final file in files) {
    final filename = file.uri.pathSegments.last;
    final key = assetKeyForFilename(filename);
    if (key == null) continue;
    final encodedName = Uri.encodeComponent(filename);
    assets.add(
      ReleaseAsset(
        key: key,
        filename: filename,
        url:
            'https://github.com/$repository/releases/download/$tag/$encodedName',
        sha256: await sha256ForFile(file),
      ),
    );
  }
  return assets;
}

String? assetKeyForFilename(String filename) {
  if (filename.endsWith('.dmg') && filename.contains('macos')) return 'macos';
  if (filename.endsWith('.exe') && filename.contains('windows')) {
    return 'windowsInstaller';
  }
  if (filename.endsWith('.zip') && filename.contains('windows')) {
    return 'windows';
  }
  if (filename.endsWith('.tar.gz') && filename.contains('linux')) {
    return 'linux';
  }
  return null;
}

Future<String> sha256ForFile(File file) async {
  final sha256sum = await Process.run('sha256sum', [file.path]);
  if (sha256sum.exitCode == 0) {
    return sha256sum.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }

  final shasum = await Process.run('shasum', ['-a', '256', file.path]);
  if (shasum.exitCode == 0) {
    return shasum.stdout.toString().trim().split(RegExp(r'\s+')).first;
  }

  fail('Unable to calculate SHA-256 for ${file.path}');
}

Future<void> writeChecksumFile(
  Directory releaseFilesDir,
  List<ReleaseAsset> assets,
) async {
  final checksums = assets
      .map((asset) => '${asset.sha256}  ${asset.filename}')
      .join('\n');
  File(
    '${releaseFilesDir.path}/SHA256SUMS.txt',
  ).writeAsStringSync(checksums.isEmpty ? '' : '$checksums\n');
}

String buildReleaseBody({
  required String tag,
  required ReleaseNotes releaseNotes,
  required List<ReleaseAsset> assets,
  String? generatedNotes,
}) {
  final buffer = StringBuffer()
    ..writeln('## Release notes')
    ..writeln()
    ..writeln('### English')
    ..writeln()
    ..writeln(releaseNotes.notes['en']!.trim())
    ..writeln();

  for (final entry in releaseNotes.notes.entries) {
    if (entry.key == 'en') continue;
    buffer
      ..writeln('### ${entry.key}')
      ..writeln()
      ..writeln(entry.value.trim())
      ..writeln();
  }

  if (assets.isNotEmpty) {
    buffer
      ..writeln('## Downloads')
      ..writeln();
    for (final asset in assets) {
      buffer.writeln('- [${asset.filename}](${asset.url})');
    }
    buffer
      ..writeln(
        '- [SHA256SUMS.txt](https://github.com/${assetRepositoryFromUrl(assets.first.url)}/releases/download/$tag/SHA256SUMS.txt)',
      )
      ..writeln();
  }

  if (generatedNotes != null && generatedNotes.trim().isNotEmpty) {
    buffer
      ..writeln('## Merged changes')
      ..writeln()
      ..writeln(generatedNotes.trim())
      ..writeln();
  }

  return buffer.toString();
}

String assetRepositoryFromUrl(String url) {
  final uri = Uri.parse(url);
  final segments = uri.pathSegments;
  if (segments.length < 2) return '';
  return '${segments[0]}/${segments[1]}';
}

void updateIndex({
  required Directory outputDir,
  required String channel,
  required String tag,
}) {
  final updatesDir = Directory('${outputDir.path}/updates')
    ..createSync(recursive: true);
  final indexFile = File('${updatesDir.path}/index.json');
  final existing = indexFile.existsSync()
      ? jsonDecode(indexFile.readAsStringSync())
      : <String, Object?>{};
  final channels = <String, Object?>{
    if (existing is Map<String, Object?> &&
        existing['channels'] is Map<String, Object?>)
      ...(existing['channels']! as Map<String, Object?>),
  };
  final tags = <String>{
    if (channels[channel] is List)
      for (final value in channels[channel]! as List) value.toString(),
    tag,
  }.toList()..sort();
  channels[channel] = tags;
  writeJson(indexFile, {
    'schemaVersion': updateSchemaVersion,
    'channels': channels,
  });
}

Future<void> restoreExistingMetadata({
  required Directory outputDir,
  required String pagesBaseUrl,
}) async {
  final normalizedBase = pagesBaseUrl.replaceFirst(RegExp(r'/$'), '');
  final indexJson = await fetchText('$normalizedBase/updates/index.json');
  if (indexJson == null) {
    await restoreLatestFallback(outputDir, normalizedBase);
    return;
  }

  final index = jsonDecode(indexJson);
  if (index is! Map<String, Object?>) return;
  writeJson(File('${outputDir.path}/updates/index.json'), index);

  final channels = index['channels'];
  if (channels is! Map<String, Object?>) return;
  for (final entry in channels.entries) {
    final channel = entry.key;
    if (entry.value is! List) continue;
    for (final tag in entry.value! as List) {
      final snapshot = await fetchText(
        '$normalizedBase/updates/$channel/$tag.json',
      );
      if (snapshot == null) continue;
      final file = File('${outputDir.path}/updates/$channel/$tag.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(snapshot);
    }
    final latest = await fetchText(
      '$normalizedBase/updates/$channel/latest.json',
    );
    if (latest != null) {
      final file = File('${outputDir.path}/updates/$channel/latest.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(latest);
    }
  }
}

Future<void> restoreLatestFallback(
  Directory outputDir,
  String normalizedBase,
) async {
  for (final channel in supportedChannels) {
    final latest = await fetchText(
      '$normalizedBase/updates/$channel/latest.json',
    );
    if (latest == null) continue;
    final latestJson = jsonDecode(latest);
    final tag = latestJson is Map<String, Object?> ? latestJson['tag'] : null;
    final channelDir = Directory('${outputDir.path}/updates/$channel')
      ..createSync(recursive: true);
    File('${channelDir.path}/latest.json').writeAsStringSync(latest);
    if (tag is String && tag.isNotEmpty) {
      File('${channelDir.path}/$tag.json').writeAsStringSync(latest);
      updateIndex(outputDir: outputDir, channel: channel, tag: tag);
    }
  }
}

Future<String?> fetchText(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return utf8.decode(
      await response.fold<List<int>>([], (bytes, chunk) {
        bytes.addAll(chunk);
        return bytes;
      }),
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

void writeJson(File file, Object? value) {
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(value)}\n');
}

Never fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
  throw StateError(message);
}

class ReleaseNotes {
  const ReleaseNotes({required this.tag, required this.notes});

  final String tag;
  final Map<String, String> notes;
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.key,
    required this.filename,
    required this.url,
    required this.sha256,
  });

  final String key;
  final String filename;
  final String url;
  final String sha256;
}

class CliOptions {
  const CliOptions(this.values);

  final Map<String, String> values;

  String? operator [](String key) => values[key];

  String required(String key) {
    final value = values[key];
    if (value == null || value.trim().isEmpty) fail('Missing --$key');
    return value;
  }

  static CliOptions parse(List<String> arguments) {
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (!argument.startsWith('--')) {
        fail('Unexpected argument: $argument');
      }
      final equals = argument.indexOf('=');
      if (equals != -1) {
        values[argument.substring(2, equals)] = argument.substring(equals + 1);
        continue;
      }
      final key = argument.substring(2);
      if (index + 1 >= arguments.length) fail('Missing value for --$key');
      values[key] = arguments[++index];
    }
    return CliOptions(values);
  }
}
