import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/home/article_reader_workspace_layout.dart';
import 'package:fleur/ui/home/home_scene_panes.dart';
import 'package:fleur/ui/sidebar_layout.dart';

void main() {
  testWidgets('reader pane keeps final layout width during reveal animation', (
    tester,
  ) async {
    final layoutWidths = <double>[];
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = oldOnError);

    Future<void> pumpLayout({required int? selectedArticleId}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: ArticleReaderWorkspaceLayout(
                selectedArticleId: selectedArticleId,
                contentWidth: 1000,
                listWidth: 600,
                listPane: const ColoredBox(color: Colors.white),
                readerPane: ReadingPaneSurface(
                  child: _ReaderPaneProbe(onLayout: layoutWidths.add),
                ),
                onResizeList: (_) {},
                showSplitHandle: selectedArticleId != null,
              ),
            ),
          ),
        ),
      );
    }

    await pumpLayout(selectedArticleId: null);
    await tester.pumpAndSettle();

    layoutWidths.clear();
    await pumpLayout(selectedArticleId: 1);
    await tester.pump(const Duration(milliseconds: 16));

    final expectedReaderWidth = 1000 - 600 - kWorkspaceSplitHandleHitWidth;

    expect(layoutWidths, isNotEmpty);
    expect(layoutWidths.last, expectedReaderWidth);
    expect(
      find.byKey(const Key('workspace_list_split_handle')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace_list_split_handle')),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('workspace_layer_leading_edge')),
      findsOneWidget,
    );
    expect(errors, isEmpty);
  });
}

class _ReaderPaneProbe extends StatelessWidget {
  const _ReaderPaneProbe({required this.onLayout});

  final ValueChanged<double> onLayout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        onLayout(constraints.maxWidth);
        return const Row(
          children: [
            SizedBox(width: 80, height: 40),
            SizedBox(width: 80, height: 40),
            SizedBox(width: 80, height: 40),
            SizedBox(width: 80, height: 40),
          ],
        );
      },
    );
  }
}
