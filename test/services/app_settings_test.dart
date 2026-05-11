import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/theme/seed_color_presets.dart';
import 'package:fleur/utils/language_utils.dart';

void main() {
  test('AppSettings defaults useDynamicColor to true', () {
    const s = AppSettings();
    expect(s.useDynamicColor, isTrue);
  });

  test('AppSettings defaults seedColorPreset to blue', () {
    const s = AppSettings();
    expect(s.seedColorPreset, SeedColorPreset.blue);
  });

  test('AppSettings defaults source refresh to disabled', () {
    const s = AppSettings();
    expect(s.sourceRefreshMinutes, isNull);
  });

  test('AppSettings persists source refresh with new JSON key', () {
    final s = const AppSettings().copyWith(sourceRefreshMinutes: 30);
    final json = s.toJson();
    expect(json['sourceRefreshMinutes'], 30);
    expect(json.containsKey('autoRefreshMinutes'), isFalse);

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(restored.sourceRefreshMinutes, 30);
  });

  test('AppSettings migrates legacy auto refresh to source refresh', () {
    final restoredFive = AppSettings.fromJson(<String, Object?>{
      'autoRefreshMinutes': 5,
    });
    final restoredThirty = AppSettings.fromJson(<String, Object?>{
      'autoRefreshMinutes': 30,
    });

    expect(restoredFive.sourceRefreshMinutes, 15);
    expect(restoredThirty.sourceRefreshMinutes, 30);
  });

  test('AppSettings persists useDynamicColor in JSON', () {
    final s = const AppSettings().copyWith(useDynamicColor: false);
    final json = s.toJson();
    expect(json['useDynamicColor'], isFalse);

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(restored.useDynamicColor, isFalse);
  });

  test('AppSettings persists seedColorPreset in JSON', () {
    final s = const AppSettings().copyWith(
      seedColorPreset: SeedColorPreset.pink,
    );
    final json = s.toJson();
    expect(json['seedColorPreset'], SeedColorPreset.pink.name);

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(restored.seedColorPreset, SeedColorPreset.pink);
  });

  test('AppSettings.fromJson defaults missing useDynamicColor to true', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'themeMode': ThemeMode.dark.name,
    });
    expect(restored.useDynamicColor, isTrue);
  });

  test('AppSettings.fromJson defaults unknown seedColorPreset to blue', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'seedColorPreset': 'totally_not_a_preset',
    });
    expect(restored.seedColorPreset, SeedColorPreset.blue);
  });

  test('AppSettings defaults remote entries limit', () {
    const s = AppSettings();
    expect(s.remoteEntriesLimit, 400);
  });

  test('AppSettings copyWith updates remote entries limit', () {
    final s = const AppSettings().copyWith(remoteEntriesLimit: 800);
    expect(s.remoteEntriesLimit, 800);
    expect(s.minifluxEntriesLimit, 800);
  });

  test('AppSettings copyWith keeps legacy Miniflux entries limit alias', () {
    final s = const AppSettings().copyWith(minifluxEntriesLimit: 900);
    expect(s.remoteEntriesLimit, 900);
  });

  test('AppSettings persists remote entries limit with legacy JSON key', () {
    final s = const AppSettings().copyWith(remoteEntriesLimit: 800);
    final json = s.toJson();
    expect(json['minifluxEntriesLimit'], 800);
    expect(json.containsKey('remoteEntriesLimit'), isFalse);

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(restored.remoteEntriesLimit, 800);
  });

  test('AppSettings.fromJson reads legacy Miniflux entries limit', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'minifluxEntriesLimit': 800,
    });
    expect(restored.remoteEntriesLimit, 800);
  });

  test('AppSettings.fromJson reads remote entries limit', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'remoteEntriesLimit': 700,
    });
    expect(restored.remoteEntriesLimit, 700);
  });

  test('AppSettings.fromJson prefers remote entries limit over legacy key', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'minifluxEntriesLimit': 800,
      'remoteEntriesLimit': 700,
    });
    expect(restored.remoteEntriesLimit, 700);
  });

  test('AppSettings.fromJson defaults missing remote entries limit', () {
    final restored = AppSettings.fromJson(<String, Object?>{});
    expect(restored.remoteEntriesLimit, 400);
  });

  test('AppSettings allows unlimited remote entries limit (0)', () {
    final s = const AppSettings().copyWith(remoteEntriesLimit: 0);
    final restored = AppSettings.fromJson(s.toJson().cast<String, Object?>());
    expect(restored.remoteEntriesLimit, 0);
  });

  test('AppSettings defaults remote fetch concurrency', () {
    const s = AppSettings();
    expect(s.remoteFetchConcurrency, 2);
  });

  test('AppSettings copyWith updates remote fetch concurrency', () {
    final s = const AppSettings().copyWith(remoteFetchConcurrency: 4);
    expect(s.remoteFetchConcurrency, 4);
  });

  test('AppSettings persists remote fetch concurrency in JSON', () {
    final s = const AppSettings().copyWith(remoteFetchConcurrency: 4);
    final json = s.toJson();
    expect(json['remoteFetchConcurrency'], 4);

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(restored.remoteFetchConcurrency, 4);
  });

  test('AppSettings.fromJson defaults missing remote fetch concurrency', () {
    final restored = AppSettings.fromJson(<String, Object?>{});
    expect(restored.remoteFetchConcurrency, 2);
  });

  test('AppSettings.fromJson defaults non-finite numeric values', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'sourceRefreshMinutes': double.infinity,
      'cleanupReadOlderThanDays': double.nan,
      'remoteEntriesLimit': double.negativeInfinity,
      'remoteFetchConcurrency': double.nan,
    });

    expect(restored.sourceRefreshMinutes, isNull);
    expect(restored.cleanupReadOlderThanDays, isNull);
    expect(restored.remoteEntriesLimit, 400);
    expect(restored.remoteFetchConcurrency, 2);
  });

  test('AppSettings normalizes remote fetch concurrency range', () {
    final low = const AppSettings(remoteFetchConcurrency: 0).normalized();
    final high = const AppSettings(remoteFetchConcurrency: 9).normalized();

    expect(low.remoteFetchConcurrency, 1);
    expect(high.remoteFetchConcurrency, 4);
  });

  test('AppSettings persists Miniflux web fetch mode in JSON', () {
    final s = const AppSettings().copyWith(
      minifluxWebFetchMode: MinifluxWebFetchMode.serverFetchContent,
    );
    final json = s.toJson();
    expect(json['minifluxWebFetchMode'], 'serverFetchContent');

    final restored = AppSettings.fromJson(json.cast<String, Object?>());
    expect(
      restored.minifluxWebFetchMode,
      MinifluxWebFetchMode.serverFetchContent,
    );
  });

  test('AppSettings normalizes equivalent app locale tags', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'localeTag': 'zh-Hans-CN',
    });
    expect(restored.localeTag, 'zh');
  });

  test('LanguageIdentity keeps normalized tag and canonical compare key', () {
    final identity = LanguageIdentity.fromTag('en-GB');
    expect(identity.normalizedTag, 'en-GB');
    expect(identity.compareKey, 'en');
    expect(identity.displayKey, 'en');
  });

  test('canonicalLanguageIdentityTag folds chinese and regional variants', () {
    expect(canonicalLanguageIdentityTag('zh-Hans-CN'), 'zh-Hans');
    expect(canonicalLanguageIdentityTag('zh-HK'), 'zh-Hant');
    expect(canonicalLanguageIdentityTag('en-GB'), 'en');
  });

  test('supportedAppLocaleForTag falls back to supported UI locales', () {
    expect(
      languageTagForLocale(supportedAppLocaleForTag('zh-Hant-HK')),
      'zh-Hant',
    );
    expect(languageTagForLocale(supportedAppLocaleForTag('fr-FR')), 'en');
  });

  test(
    'defaultTargetLanguageTagForAppLocale preserves system language identity',
    () {
      expect(
        defaultTargetLanguageTagForAppLocale(
          null,
          const Locale.fromSubtags(languageCode: 'fr', countryCode: 'FR'),
        ),
        'fr',
      );
      expect(
        defaultTargetLanguageTagForAppLocale(
          'zh-Hant-HK',
          const Locale.fromSubtags(languageCode: 'fr', countryCode: 'FR'),
        ),
        'zh-Hant',
      );
    },
  );

  test('localizedLanguageNameForTag shows canonical chinese name', () {
    expect(
      localizedLanguageNameForTag(const Locale('en'), 'zh-Hans-CN'),
      'Chinese (Simplified)',
    );
    expect(
      localizedLanguageNameForTag(const Locale('zh'), 'zh-Hant-HK'),
      '繁體中文',
    );
  });
}
