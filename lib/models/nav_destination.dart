enum GlobalNavDestination { feeds, saved, search, settings }

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

GlobalNavDestination destinationForUri(Uri uri) {
  final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  return switch (seg) {
    'starred' || 'read-later' => GlobalNavDestination.saved,
    'search' => GlobalNavDestination.search,
    'settings' => GlobalNavDestination.settings,
    // Canonical reading workspace scopes live under the Feeds section.
    '' || 'all' || 'feed' || 'category' || 'tag' => GlobalNavDestination.feeds,
    _ => GlobalNavDestination.feeds,
  };
}

int globalDestinationIndex(GlobalNavDestination d) =>
    GlobalNavDestination.values.indexOf(d);

String destinationLocation(GlobalNavDestination d) => switch (d) {
  GlobalNavDestination.feeds => '/all',
  GlobalNavDestination.saved => '/starred',
  GlobalNavDestination.search => '/search',
  GlobalNavDestination.settings => settingsLocation(),
};

String settingsLocation({SettingsTab? tab}) {
  if (tab == null) return '/settings';
  return Uri(
    path: '/settings',
    queryParameters: {'tab': tab.queryValue},
  ).toString();
}
