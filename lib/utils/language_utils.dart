import 'package:flutter/material.dart';

const String unknownLanguageTag = 'unknown';

class LanguageIdentity {
  const LanguageIdentity({
    required this.rawTag,
    required this.normalizedTag,
    required this.compareKey,
    required this.displayKey,
  });

  factory LanguageIdentity.fromTag(String? tag) {
    final raw = (tag ?? '').trim();
    final normalized = normalizeLanguageTag(raw);
    final compareKey = canonicalLanguageIdentityTag(normalized);
    return LanguageIdentity(
      rawTag: raw,
      normalizedTag: normalized,
      compareKey: compareKey,
      displayKey: compareKey,
    );
  }

  final String rawTag;
  final String normalizedTag;
  final String compareKey;
  final String displayKey;

  bool get isKnown => compareKey != unknownLanguageTag;
}

Locale localeFromLanguageTag(String tag) {
  final normalized = normalizeLanguageTag(tag);
  if (normalized.isEmpty) return const Locale('und');
  final parts = normalized.split('-');
  final languageCode = parts.isEmpty ? 'und' : parts.first;
  String? scriptCode;
  String? countryCode;

  if (parts.length >= 2) {
    final p1 = parts[1];
    if (p1.length == 4) {
      scriptCode = p1;
    } else if (p1.length == 2 || p1.length == 3) {
      countryCode = p1;
    }
  }
  if (parts.length >= 3) {
    final p2 = parts[2];
    if (scriptCode == null && p2.length == 4) {
      scriptCode = p2;
    } else if (countryCode == null && (p2.length == 2 || p2.length == 3)) {
      countryCode = p2;
    }
  }

  return Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}

String normalizeLanguageTag(String tag) {
  final raw = tag.trim();
  if (raw.isEmpty) return '';
  final parts = raw
      .replaceAll('_', '-')
      .split('-')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '';

  final languageCode = parts.first.toLowerCase();
  String? scriptCode;
  String? regionCode;

  for (final p in parts.skip(1)) {
    if (p.length == 4 && scriptCode == null) {
      scriptCode = '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
      continue;
    }
    if ((p.length == 2 || p.length == 3) && regionCode == null) {
      regionCode = p.toUpperCase();
      continue;
    }
  }

  final out = <String>[
    languageCode,
    ...?(scriptCode == null ? null : [scriptCode]),
    ...?(regionCode == null ? null : [regionCode]),
  ];
  return out.join('-');
}

String canonicalLanguageIdentityTag(String tag) {
  final normalized = normalizeLanguageTag(tag);
  if (normalized.isEmpty || normalized == 'und') return unknownLanguageTag;

  final locale = localeFromLanguageTag(normalized);
  final languageCode = locale.languageCode.trim().toLowerCase();
  final scriptCode = locale.scriptCode?.trim();
  final countryCode = locale.countryCode?.trim().toUpperCase();

  if (languageCode.isEmpty || languageCode == 'und') return unknownLanguageTag;

  if (languageCode == 'zh') {
    if (scriptCode == 'Hant' ||
        countryCode == 'TW' ||
        countryCode == 'HK' ||
        countryCode == 'MO') {
      return 'zh-Hant';
    }
    return 'zh-Hans';
  }

  if (languageCode == 'pt' && countryCode == 'BR') {
    return 'pt-BR';
  }

  return languageCode;
}

String normalizeAppLocaleTag(String tag) {
  final normalized = normalizeLanguageTag(tag);
  if (normalized.isEmpty) return '';
  return switch (canonicalLanguageIdentityTag(normalized)) {
    'zh-Hant' => 'zh-Hant',
    'zh-Hans' => 'zh-Hans',
    'en' => 'en',
    'de' => 'de',
    'es' => 'es',
    'fr' => 'fr',
    'ja' => 'ja',
    'ko' => 'ko',
    'pt' => 'pt-BR',
    'pt-BR' => 'pt-BR',
    _ => normalized,
  };
}

String runtimeLanguageTagForAppLocale(
  String? appLocaleTag,
  Locale systemLocale,
) {
  final raw = (appLocaleTag ?? '').trim();
  if (raw.isNotEmpty) return normalizeLanguageTag(raw);
  return languageTagForLocale(systemLocale);
}

String defaultTargetLanguageTagForAppLocale(
  String? appLocaleTag,
  Locale systemLocale,
) {
  final compareKey = canonicalLanguageIdentityTag(
    runtimeLanguageTagForAppLocale(appLocaleTag, systemLocale),
  );
  return compareKey == unknownLanguageTag ? 'en' : compareKey;
}

Locale supportedAppLocaleForTag(String? languageTag) {
  final appLocaleTag = normalizeAppLocaleTag(languageTag ?? '');
  return switch (appLocaleTag) {
    'zh-Hant' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    'zh-Hans' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    'de' => const Locale('de'),
    'es' => const Locale('es'),
    'fr' => const Locale('fr'),
    'ja' => const Locale('ja'),
    'ko' => const Locale('ko'),
    'pt-BR' => const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR'),
    'en' => const Locale('en'),
    _ => const Locale('en'),
  };
}

bool isKnownLanguageIdentityTag(String? tag) {
  if (tag == null || tag.trim().isEmpty) return false;
  return canonicalLanguageIdentityTag(tag) != unknownLanguageTag;
}

String? canonicalKnownLanguageTagOrNull(String? tag) {
  final compareKey = canonicalLanguageIdentityTag(tag ?? '');
  if (compareKey == unknownLanguageTag) return null;
  return compareKey;
}

String languageTagForLocale(Locale locale) {
  final languageCode = locale.languageCode.trim().isEmpty
      ? 'und'
      : locale.languageCode.trim();
  final scriptCode = locale.scriptCode?.trim();
  final countryCode = locale.countryCode?.trim();
  final out = <String>[
    languageCode,
    if (scriptCode != null && scriptCode.isNotEmpty) scriptCode,
    if (countryCode != null && countryCode.isNotEmpty) countryCode,
  ];
  return normalizeLanguageTag(out.join('-'));
}

String localizedLanguageNameForTag(Locale uiLocale, String languageTag) {
  final uiTag = languageTagForLocale(
    supportedAppLocaleForTag(languageTagForLocale(uiLocale)),
  );
  final ui = canonicalLanguageIdentityTag(uiTag);
  final tag = canonicalLanguageIdentityTag(languageTag);

  final names = _localizedLanguageNames[ui] ?? _localizedLanguageNames['en']!;
  final name = names[tag];
  if (name != null) return name;

  final normalized = normalizeLanguageTag(languageTag);
  return normalized.isEmpty ? languageTag : normalized;
}

const Map<String, Map<String, String>> _localizedLanguageNames = {
  'en': {
    'en': 'English',
    'zh-Hans': 'Chinese (Simplified)',
    'zh-Hant': 'Chinese (Traditional)',
    'ja': 'Japanese',
    'ko': 'Korean',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'pt-BR': 'Portuguese (Brazil)',
  },
  'zh-Hans': {
    'en': '英文',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
    'ja': '日文',
    'ko': '韩文',
    'fr': '法文',
    'de': '德文',
    'es': '西班牙文',
    'ru': '俄文',
    'pt': '葡萄牙文',
    'pt-BR': '葡萄牙文（巴西）',
  },
  'zh-Hant': {
    'en': '英文',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
    'ja': '日文',
    'ko': '韓文',
    'fr': '法文',
    'de': '德文',
    'es': '西班牙文',
    'ru': '俄文',
    'pt': '葡萄牙文',
    'pt-BR': '葡萄牙文（巴西）',
  },
  'de': {
    'en': 'Englisch',
    'zh-Hans': 'Chinesisch (vereinfacht)',
    'zh-Hant': 'Chinesisch (traditionell)',
    'ja': 'Japanisch',
    'ko': 'Koreanisch',
    'fr': 'Französisch',
    'de': 'Deutsch',
    'es': 'Spanisch',
    'ru': 'Russisch',
    'pt': 'Portugiesisch',
    'pt-BR': 'Portugiesisch (Brasilien)',
  },
  'es': {
    'en': 'Inglés',
    'zh-Hans': 'Chino (simplificado)',
    'zh-Hant': 'Chino (tradicional)',
    'ja': 'Japonés',
    'ko': 'Coreano',
    'fr': 'Francés',
    'de': 'Alemán',
    'es': 'Español',
    'ru': 'Ruso',
    'pt': 'Portugués',
    'pt-BR': 'Portugués (Brasil)',
  },
  'fr': {
    'en': 'Anglais',
    'zh-Hans': 'Chinois (simplifié)',
    'zh-Hant': 'Chinois (traditionnel)',
    'ja': 'Japonais',
    'ko': 'Coréen',
    'fr': 'Français',
    'de': 'Allemand',
    'es': 'Espagnol',
    'ru': 'Russe',
    'pt': 'Portugais',
    'pt-BR': 'Portugais (Brésil)',
  },
  'ja': {
    'en': '英語',
    'zh-Hans': '簡体字中国語',
    'zh-Hant': '繁体字中国語',
    'ja': '日本語',
    'ko': '韓国語',
    'fr': 'フランス語',
    'de': 'ドイツ語',
    'es': 'スペイン語',
    'ru': 'ロシア語',
    'pt': 'ポルトガル語',
    'pt-BR': 'ポルトガル語（ブラジル）',
  },
  'ko': {
    'en': '영어',
    'zh-Hans': '중국어(간체)',
    'zh-Hant': '중국어(번체)',
    'ja': '일본어',
    'ko': '한국어',
    'fr': '프랑스어',
    'de': '독일어',
    'es': '스페인어',
    'ru': '러시아어',
    'pt': '포르투갈어',
    'pt-BR': '포르투갈어(브라질)',
  },
  'pt-BR': {
    'en': 'Inglês',
    'zh-Hans': 'Chinês (simplificado)',
    'zh-Hant': 'Chinês (tradicional)',
    'ja': 'Japonês',
    'ko': 'Coreano',
    'fr': 'Francês',
    'de': 'Alemão',
    'es': 'Espanhol',
    'ru': 'Russo',
    'pt': 'Português',
    'pt-BR': 'Português (Brasil)',
  },
};
