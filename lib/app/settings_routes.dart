enum SettingsTab {
  appPreferences,
  appearance,
  subscriptions,
  groupingAndSorting,
  services,
  translationAndAiServices,
  about,
}

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

SettingsTab? settingsTabFromQueryValue(String? value) {
  if (value == null) return null;
  for (final tab in SettingsTab.values) {
    if (tab.queryValue == value) return tab;
  }
  return null;
}

String settingsLocation({SettingsTab? tab, String? setting}) {
  if (tab == null) return '/settings';
  final queryParameters = <String, String>{'tab': tab.queryValue};
  if (setting != null && setting.trim().isNotEmpty) {
    queryParameters['setting'] = setting.trim();
  }
  return Uri(path: '/settings', queryParameters: queryParameters).toString();
}
