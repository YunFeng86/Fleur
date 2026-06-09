import 'dart:ui';

enum AppUpdateChannel {
  stable,
  beta;

  static AppUpdateChannel parse(String value) {
    return switch (value) {
      'stable' => AppUpdateChannel.stable,
      'beta' => AppUpdateChannel.beta,
      _ => throw FormatException('Unsupported update channel: $value'),
    };
  }

  String get wireName => switch (this) {
    AppUpdateChannel.stable => 'stable',
    AppUpdateChannel.beta => 'beta',
  };
}

class AppUpdateAsset {
  const AppUpdateAsset({required this.url, this.sha256});

  final Uri url;
  final String? sha256;

  factory AppUpdateAsset.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Update asset must be an object');
    }
    final url = _requiredString(value, 'url');
    return AppUpdateAsset(
      url: _parseUri(url, 'asset url'),
      sha256: _optionalString(value, 'sha256'),
    );
  }
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.schemaVersion,
    required this.channel,
    required this.version,
    required this.tag,
    required this.publishedAt,
    required this.releaseUrl,
    required this.notes,
    required this.assets,
  });

  final int schemaVersion;
  final AppUpdateChannel channel;
  final String version;
  final String tag;
  final DateTime? publishedAt;
  final Uri releaseUrl;
  final Map<String, String> notes;
  final Map<String, AppUpdateAsset> assets;

  factory AppUpdateManifest.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Update manifest must be an object');
    }

    final schemaVersion = value['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw FormatException('Unsupported update schema: $schemaVersion');
    }

    final notes = _parseNotes(value['notes']);
    if ((notes['en'] ?? '').trim().isEmpty) {
      throw const FormatException('Update manifest requires English notes');
    }

    return AppUpdateManifest(
      schemaVersion: schemaVersion,
      channel: AppUpdateChannel.parse(_requiredString(value, 'channel')),
      version: _requiredString(value, 'version'),
      tag: _requiredString(value, 'tag'),
      publishedAt: _optionalDateTime(value, 'publishedAt'),
      releaseUrl: _parseUri(_requiredString(value, 'releaseUrl'), 'releaseUrl'),
      notes: notes,
      assets: _parseAssets(value['assets']),
    );
  }

  String notesForLocale(Locale? locale) {
    final candidates = <String>[
      if (locale != null) locale.toLanguageTag(),
      if (locale != null && locale.scriptCode != null)
        '${locale.languageCode}_${locale.scriptCode}',
      if (locale != null && locale.countryCode != null)
        '${locale.languageCode}_${locale.countryCode}',
      if (locale != null) locale.languageCode,
      'en',
    ];

    for (final candidate in candidates) {
      final notesValue = notes[candidate]?.trim();
      if (notesValue != null && notesValue.isNotEmpty) return notesValue;
    }
    return notes.values.firstWhere((value) => value.trim().isNotEmpty);
  }
}

Map<String, String> _parseNotes(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Update notes must be an object');
  }
  return value.map((key, value) {
    if (value is! String) {
      throw FormatException('Update note for "$key" must be a string');
    }
    return MapEntry(key, value);
  });
}

Map<String, AppUpdateAsset> _parseAssets(Object? value) {
  if (value == null) return const {};
  if (value is! Map<String, Object?>) {
    throw const FormatException('Update assets must be an object');
  }
  return value.map(
    (key, value) => MapEntry(key, AppUpdateAsset.fromJson(value)),
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Update manifest requires "$key"');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Update manifest "$key" must be a string');
  }
  return value.trim().isEmpty ? null : value;
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Update manifest "$key" must be an ISO timestamp');
  }
  return DateTime.tryParse(value);
}

Uri _parseUri(String value, String fieldName) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw FormatException('Invalid update $fieldName: $value');
  }
  return uri;
}
