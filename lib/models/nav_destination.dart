enum GlobalNavDestination { feeds, saved, search, settings }

GlobalNavDestination destinationForUri(Uri uri) {
  final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  return switch (seg) {
    'saved' => GlobalNavDestination.saved,
    'search' => GlobalNavDestination.search,
    'settings' => GlobalNavDestination.settings,
    // article + home live under the Feeds section.
    '' || 'article' => GlobalNavDestination.feeds,
    _ => GlobalNavDestination.feeds,
  };
}

int globalDestinationIndex(GlobalNavDestination d) =>
    GlobalNavDestination.values.indexOf(d);

String destinationLocation(GlobalNavDestination d) => switch (d) {
  GlobalNavDestination.feeds => '/',
  GlobalNavDestination.saved => '/saved',
  GlobalNavDestination.search => '/search',
  GlobalNavDestination.settings => '/settings',
};
