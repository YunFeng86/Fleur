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

  test('code appearance font stack keywords are searchable', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'font stack',
    );

    expect(
      results.map((entry) => entry.id),
      contains('appearance.fonts.advanced'),
    );
  });

  test('monospace searches advanced font settings', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'monospace',
    );

    expect(results.map((entry) => entry.id), contains('appearance.code.font'));
    expect(
      results
          .firstWhere((entry) => entry.id == 'appearance.code.font')
          .targetId,
      'appearance.fonts.advanced',
    );
  });

  test('localized code appearance entries are searchable', () {
    final zh = AppLocalizationsZh();
    final fontResults = searchSettingsEntries(
      buildSettingsSearchEntries(zh),
      '代码字体',
    );
    final wrapResults = searchSettingsEntries(
      buildSettingsSearchEntries(zh),
      '自动换行',
    );

    expect(fontResults.first.id, 'appearance.code.font');
    expect(fontResults.first.targetId, 'appearance.fonts.advanced');
    expect(wrapResults.first.id, 'appearance.code.wrap');
  });

  test('localized advanced font settings entries are searchable', () {
    final zh = AppLocalizationsZh();
    final minimumResults = searchSettingsEntries(
      buildSettingsSearchEntries(zh),
      '最小字号',
    );
    final mathResults = searchSettingsEntries(
      buildSettingsSearchEntries(zh),
      '数学字体',
    );

    expect(minimumResults.first.id, 'appearance.fonts.advanced');
    expect(mathResults.first.id, 'appearance.fonts.advanced');
  });

  test('no matching query returns empty list', () {
    final results = searchSettingsEntries(
      buildSettingsSearchEntries(en),
      'zzzz-not-a-setting',
    );

    expect(results, isEmpty);
  });
}
