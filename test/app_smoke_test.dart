import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_reader/app/app.dart';
import 'package:flutter_reader/app/router.dart';

void main() {
  testWidgets('App builds', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(App), findsOneWidget);
  });
}
