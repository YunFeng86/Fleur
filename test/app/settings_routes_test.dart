import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/app/settings_routes.dart';

void main() {
  test('settings locations use path segments for pages and details', () {
    expect(settingsLocation(), '/settings');
    expect(
      settingsLocation(tab: SettingsTab.appearance),
      '/settings/appearance',
    );
    expect(
      settingsLocation(
        tab: SettingsTab.appearance,
        detail: SettingsDetail.appearanceFonts,
      ),
      '/settings/appearance/fonts',
    );
    expect(
      settingsLocation(
        tab: SettingsTab.appearance,
        setting: 'appearance.theme.mode',
      ),
      '/settings/appearance?setting=appearance.theme.mode',
    );
  });

  test('settings details are only valid below their owning tab', () {
    expect(
      settingsDetailFromPath(SettingsTab.appearance, 'fonts'),
      SettingsDetail.appearanceFonts,
    );
    expect(settingsDetailFromPath(SettingsTab.services, 'fonts'), isNull);
    expect(settingsDetailFromPath(SettingsTab.appearance, 'unknown'), isNull);
  });
}
