import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/app/settings_routes.dart';
import 'package:fleur/l10n/app_localizations_en.dart';
import 'package:fleur/l10n/app_localizations_zh.dart';
import 'package:fleur/ui/settings/settings_search_index.dart';

void main() {
  final en = AppLocalizationsEn();

  test('empty query returns top-level settings pages', () {
    final results = searchSettingsEntries(buildSettingsSearchEntries(en), '');

    expect(results.map((entry) => entry.id), [
      'page.${SettingsTab.appPreferences.queryValue}',
      'page.${SettingsTab.appearance.queryValue}',
      'page.${SettingsTab.subscriptions.queryValue}',
      'page.${SettingsTab.groupingAndSorting.queryValue}',
      'page.${SettingsTab.services.queryValue}',
      'page.${SettingsTab.translationAndAiServices.queryValue}',
      'page.${SettingsTab.about.queryValue}',
    ]);
  });

  test('search is case-insensitive and prefers title matches', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'FONT',
    );

    expect(results.first.id, 'appearance.reader.font_family');
    expect(results.first.tab, SettingsTab.appearance);
  });

  test('keywords match settings entries', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'material you',
    );

    expect(results.first.id, 'appearance.theme.colors');
  });

  test('localized titles are searchable', () {
    final zh = AppLocalizationsZh();
    final results = searchSettingsEntries(buildSettingsSearchEntries(zh), '字号');

    expect(results.first.id, 'appearance.reader.font_size');
  });

  test('reader texture keywords are searchable', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'texture',
    );

    expect(results.first.id, 'appearance.reader.theme');
  });

  test('localized reader texture is searchable', () {
    final zh = AppLocalizationsZh();
    final results = searchSettingsEntries(buildSettingsSearchEntries(zh), '质感');

    expect(results.first.id, 'appearance.reader.theme');
  });

  test('localized reading width is searchable', () {
    final zh = AppLocalizationsZh();
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(zh),
      '阅读宽度',
    );

    expect(results.first.id, 'appearance.reader.width');
  });

  test('no matching query returns empty list', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'zzzz-not-a-setting',
    );

    expect(results, isEmpty);
  });
}
