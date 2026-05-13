enum SettingsTab {
  appPreferences,
  subscriptions,
  groupingAndSorting,
  services,
  translationAndAiServices,
  about,
}

extension SettingsTabX on SettingsTab {
  String get queryValue => switch (this) {
    SettingsTab.appPreferences => 'app-preferences',
    SettingsTab.subscriptions => 'subscriptions',
    SettingsTab.groupingAndSorting => 'grouping-and-sorting',
    SettingsTab.services => 'services',
    SettingsTab.translationAndAiServices => 'translation-and-ai-services',
    SettingsTab.about => 'about',
  };
}

SettingsTab? settingsTabFromQueryValue(String? value) {
  if (value == null) return null;
  for (final tab in SettingsTab.values) {
    if (tab.queryValue == value) return tab;
  }
  return null;
}

String settingsLocation({SettingsTab? tab}) {
  if (tab == null) return '/settings';
  return Uri(
    path: '/settings',
    queryParameters: {'tab': tab.queryValue},
  ).toString();
}
