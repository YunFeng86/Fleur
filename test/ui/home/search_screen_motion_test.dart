import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/search_routes.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/home/search_screen.dart';

import '../../test_utils/critical_workflow_test_support.dart';

class _EmptyArticleListController extends ArticleListController {
  @override
  Future<ArticleListState> build() async {
    return const ArticleListState(items: [], hasMore: false, nextOffset: 0);
  }
}

void main() {
  testWidgets('search filters honor reduced motion', (tester) async {
    final router = GoRouter(
      initialLocation: '/search?q=reader',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => SearchScreen(
            selectedArticleId: null,
            routeState: searchStateFromUri(state.uri),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search_advanced_filters')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.byKey(const Key('search_filter_switcher')),
          )
          .duration,
      Duration.zero,
    );
  });
}
