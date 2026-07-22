import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/app_shell.dart';
import 'package:fleur/ui/workspace_layers.dart';

import 'critical_workflow_test_support.dart';

Widget buildShellHarness({
  Uri? currentUri,
  Widget? child,
  MediaQueryData? mediaQueryData,
  List<Override> overrides = const [],
}) {
  final shell = AppShell(
    currentUri: currentUri ?? Uri(path: '/'),
    child:
        child ??
        const ColoredBox(
          key: Key('app_shell_child'),
          color: Colors.transparent,
        ),
  );
  return ProviderScope(
    overrides: [
      activeAccountProvider.overrideWithValue(buildTestAccount()),
      feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
      categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
      tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
      allUnreadCountsProvider.overrideWith(
        (ref) => Stream.value(<int?, int>{}),
      ),
      outboxPendingCountProvider.overrideWith((ref) async => 0),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: mediaQueryData == null
          ? shell
          : MediaQuery(data: mediaQueryData, child: shell),
    ),
  );
}

void expectWorkspaceSurfaceAppearance(
  WidgetTester tester,
  Key key, {
  required BorderRadius borderRadius,
  required bool showShadow,
  required WorkspaceLayerEdge leadingEdge,
}) {
  final surface = tester.widget<WorkspaceLayerSurface>(find.byKey(key));
  expect(surface.borderRadius, borderRadius);
  expect(surface.showShadow, showShadow);
  expect(surface.leadingEdge, leadingEdge);
}
