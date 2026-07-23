enum SettingsTab {
  appPreferences,
  appearance,
  subscriptions,
  groupingAndSorting,
  services,
  translationAndAiServices,
  about,
}

enum SettingsDetail { appearanceFonts }

extension SettingsTabX on SettingsTab {
  String get queryValue => switch (this) {
    SettingsTab.appPreferences => 'app-preferences',
    SettingsTab.appearance => 'appearance',
    SettingsTab.subscriptions => 'subscriptions',
    SettingsTab.groupingAndSorting => 'grouping-and-sorting',
    SettingsTab.services => 'services',
    SettingsTab.translationAndAiServices => 'translation-and-ai-services',
    SettingsTab.about => 'about',
  };
}

extension SettingsDetailX on SettingsDetail {
  SettingsTab get tab => switch (this) {
    SettingsDetail.appearanceFonts => SettingsTab.appearance,
  };

  String get pathSegment => switch (this) {
    SettingsDetail.appearanceFonts => 'fonts',
  };
}

SettingsTab? settingsTabFromQueryValue(String? value) {
  if (value == null) return null;
  for (final tab in SettingsTab.values) {
    if (tab.queryValue == value) return tab;
  }
  return null;
}

SettingsDetail? settingsDetailFromPath(SettingsTab tab, String? value) {
  if (value == null) return null;
  for (final detail in SettingsDetail.values) {
    if (detail.tab == tab && detail.pathSegment == value) return detail;
  }
  return null;
}

String settingsLocation({
  SettingsTab? tab,
  SettingsDetail? detail,
  String? setting,
}) {
  assert(detail == null || tab == detail.tab);
  if (tab == null) return '/settings';
  final pathSegments = <String>['settings', tab.queryValue];
  if (detail != null) pathSegments.add(detail.pathSegment);
  final queryParameters = <String, String>{};
  if (setting != null && setting.trim().isNotEmpty) {
    queryParameters['setting'] = setting.trim();
  }
  return Uri(
    path: '/${pathSegments.join('/')}',
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  ).toString();
}
