import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:fleur/features/reader/reader.dart' show ReaderWidgetFactory;
import 'package:fleur/services/settings/reader_settings.dart';

class _NoopCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unexpected cache manager access: ${invocation.memberName}',
    );
  }
}

void main() {
  const html =
      '<p><a href="https://example.com/a">link a</a> and '
      '<a href="https://example.com/b">link b</a></p>';

  testWidgets(
    'recognizer url map stays bounded across rebuilds and clears on dispose',
    (tester) async {
      final recognizerUrlMap = <int, String>{};
      final cacheManager = _NoopCacheManager();

      HtmlWidget buildHtml({Key? key}) => HtmlWidget(
        html,
        key: key,
        factoryBuilder: () => ReaderWidgetFactory(
          cacheManager,
          settings: const ReaderSettings(),
          recognizerUrlMap: recognizerUrlMap,
        ),
        renderMode: RenderMode.column,
        // Sync build keeps recognizer registration deterministic in the test
        // env; the factory dispose path is identical to the async pipeline.
        buildAsync: false,
        onTapUrl: (_) async => true,
      );

      Future<void> pumpHtml(WidgetTester tester, {Key? key}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: buildHtml(key: key)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      await pumpHtml(tester, key: UniqueKey());
      expect(recognizerUrlMap.values.toSet(), {
        'https://example.com/a',
        'https://example.com/b',
      });

      // Repeated rebuilds with fresh keys mirror chunk re-keying during
      // scrolling and search highlighting: each rebuild creates a new factory
      // and new recognizers, and stale entries must be dropped on dispose.
      for (var i = 0; i < 5; i++) {
        await pumpHtml(tester, key: UniqueKey());
      }
      expect(
        recognizerUrlMap.length,
        2,
        reason: 'stale recognizer entries must be removed on rebuild',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(recognizerUrlMap, isEmpty);
    },
  );
}
