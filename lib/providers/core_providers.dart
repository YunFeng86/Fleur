import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../ui/sidebar_layout.dart';

// Overridden in `main.dart` after opening the database.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden in main()');
});

final sidebarVisibleProvider = StateProvider<bool>((ref) => true);

final sidebarPresentationModeProvider = StateProvider<SidebarPresentationMode>(
  (ref) => SidebarPresentationMode.expanded,
);

final macOSWindowChromeMetricsProvider =
    StateProvider<MacOSWindowChromeMetrics>(
      (ref) => MacOSWindowChromeMetrics.fallback,
    );
