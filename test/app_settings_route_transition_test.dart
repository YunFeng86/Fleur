import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/router.dart';
import 'package:fleur/app/settings_routes.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/ui/home/reading_workspace_screen.dart';
import 'package:fleur/ui/settings/settings_screen.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/utils/platform.dart';

import 'test_utils/critical_workflow_test_support.dart';

class _EmptyArticleListController extends ArticleListController {
  @override
  Future<ArticleListState> build() async {
    return const ArticleListState(items: [], hasMore: false, nextOffset: 0);
  }
}

void main() {
  testWidgets(
    'settings swaps shell scenes without an overlapping route frame',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            readerSettingsStoreProvider.overrideWithValue(
              FakeReaderSettingsStore(const ReaderSettings()),
            ),
            articleListControllerProvider.overrideWith(
              _EmptyArticleListController.new,
            ),
            feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0}),
            ),
            outboxPendingCountProvider.overrideWith((ref) async => 0),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: AppTheme.light(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      addTearDown(() => router.dispose());
      await tester.pumpAndSettle();

      expect(find.byType(ReadingWorkspaceScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      final globalToolArea = find.byKey(const Key('shell_global_tool_area'));
      expect(globalToolArea, findsOneWidget);
      final globalToolElement = tester.element(globalToolArea);

      router.go('/settings');
      await tester.pump();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ReadingWorkspaceScreen), findsNothing);
      expect(tester.element(globalToolArea), same(globalToolElement));
      final settingsScreenElement = tester.element(find.byType(SettingsScreen));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings_nav_appearance')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings/appearance',
      );
      await tester.tap(find.byKey(const Key('shell_sidebar_button')));
      await tester.pumpAndSettle();

      final backButtonLeft = tester
          .getTopLeft(find.byKey(const Key('settings_back_button')))
          .dx;
      final bodyContentLeft = tester.getTopLeft(find.text('App appearance')).dx;
      expect(backButtonLeft, closeTo(bodyContentLeft, 1));

      await tester.tap(find.byKey(const Key('shell_sidebar_button')));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(SettingsScreen)),
        same(settingsScreenElement),
      );
      await tester.ensureVisible(
        find.byKey(const Key('appearance_advanced_fonts_tile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appearance_advanced_fonts_tile')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings/appearance/fonts',
      );
      expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
      expect(
        find.byKey(const Key('appearance_fonts_back_button')),
        findsNothing,
      );
      expect(
        tester.element(find.byType(SettingsScreen)),
        same(settingsScreenElement),
      );

      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings/appearance',
      );

      router.go(
        settingsLocation(
          tab: SettingsTab.appearance,
          detail: SettingsDetail.appearanceFonts,
        ),
      );
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings/appearance',
      );
      expect(tester.element(globalToolArea), same(globalToolElement));

      router.go(
        settingsLocation(
          tab: SettingsTab.appearance,
          detail: SettingsDetail.appearanceFonts,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shell_back_button')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings/appearance',
      );

      await tester.tap(find.byKey(const Key('shell_back_button')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings',
      );

      await tester.tap(find.byKey(const Key('shell_back_button')));
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final settingsVisible = find
            .byType(SettingsScreen)
            .evaluate()
            .isNotEmpty;
        final workspaceVisible = find
            .byType(ReadingWorkspaceScreen)
            .evaluate()
            .isNotEmpty;
        expect(settingsVisible && workspaceVisible, isFalse);
        if (workspaceVisible) {
          expect(find.byKey(const Key('settings_sidebar')), findsNothing);
          expect(
            find.byKey(const Key('settings_navigation_rail')),
            findsNothing,
          );
        }
      }
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(ReadingWorkspaceScreen), findsOneWidget);
      expect(tester.element(globalToolArea), same(globalToolElement));
      expect(tester.takeException(), isNull);
    },
  );
}
