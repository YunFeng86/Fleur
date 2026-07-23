import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/home/article_reader_workspace_layout.dart';
import 'package:fleur/ui/home/home_scene_panes.dart';
import 'package:fleur/ui/motion.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/workspace_layers.dart';

void main() {
  testWidgets('retiring reader leaves focus and semantics immediately', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final readerFocusNode = FocusNode(debugLabel: 'test reader focus');
    addTearDown(readerFocusNode.dispose);

    Future<void> pumpLayout({required int? selectedArticleId}) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1000,
            height: 600,
            child: ArticleReaderWorkspaceLayout(
              selectedArticleId: selectedArticleId,
              contentWidth: 1000,
              listWidth: 600,
              listPane: const ColoredBox(color: Colors.white),
              readerPane: Semantics(
                label: 'Reader content',
                child: Focus(
                  focusNode: readerFocusNode,
                  autofocus: true,
                  child: const SizedBox(key: Key('retained_reader_content')),
                ),
              ),
              onResizeList: (_) {},
              showSplitHandle: true,
            ),
          ),
        ),
      );
    }

    await pumpLayout(selectedArticleId: 1);
    await tester.pumpAndSettle();

    expect(readerFocusNode.hasFocus, isTrue);
    expect(find.bySemanticsLabel('Reader content'), findsOneWidget);

    await pumpLayout(selectedArticleId: null);
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(const Key('retained_reader_content')), findsOneWidget);
    expect(readerFocusNode.hasFocus, isFalse);
    expect(
      tester
          .widget<ExcludeSemantics>(
            find.byKey(
              const Key('article_reader_workspace_reader_semantics_gate'),
            ),
          )
          .excluding,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('retained_reader_content')))
          .parent,
      isNull,
    );

    await tester.pump(AppMotion.medium);
    expect(find.byKey(const Key('retained_reader_content')), findsNothing);
    semantics.dispose();
  });

  testWidgets('reduced motion removes retiring reader immediately', (
    tester,
  ) async {
    Future<void> pumpLayout({required int? selectedArticleId}) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 1000,
              height: 600,
              child: ArticleReaderWorkspaceLayout(
                selectedArticleId: selectedArticleId,
                contentWidth: 1000,
                listWidth: 600,
                listPane: const ColoredBox(color: Colors.white),
                readerPane: const SizedBox(
                  key: Key('reduced_motion_reader_content'),
                ),
                onResizeList: (_) {},
                showSplitHandle: true,
              ),
            ),
          ),
        ),
      );
    }

    await pumpLayout(selectedArticleId: 1);
    await tester.pump();
    expect(
      find.byKey(const Key('reduced_motion_reader_content')),
      findsOneWidget,
    );

    await pumpLayout(selectedArticleId: null);
    await tester.pump();
    expect(
      find.byKey(const Key('reduced_motion_reader_content')),
      findsNothing,
    );
  });

  testWidgets('reader pane keeps final layout width during reveal animation', (
    tester,
  ) async {
    final layoutWidths = <double>[];
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = errors.add;

    try {
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

      const expectedReaderWidth = 1000 - 600.0;

      expect(layoutWidths, isNotEmpty);
      expect(layoutWidths.last, expectedReaderWidth);
      expect(
        find.byKey(const Key('workspace_list_split_handle')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      final splitHandleRect = tester.getRect(
        find.byKey(const Key('article_reader_workspace_split_layer')),
      );
      expect(splitHandleRect.center.dx, closeTo(600, 0.1));
      expect(splitHandleRect.width, kWorkspaceSplitHandleHitWidth);
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
    } finally {
      FlutterError.onError = oldOnError;
    }
  });

  testWidgets('workspace layer edge levels use the same painter slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: const [
            SizedBox(
              width: 120,
              height: 160,
              child: WorkspaceLayerSurface(
                leadingEdge: WorkspaceLayerEdge.level1,
                child: SizedBox.expand(),
              ),
            ),
            SizedBox(
              width: 120,
              height: 160,
              child: WorkspaceLayerSurface(
                leadingEdge: WorkspaceLayerEdge.level2,
                child: SizedBox.expand(),
              ),
            ),
            SizedBox(
              width: 120,
              height: 160,
              child: WorkspaceLayerSurface(child: SizedBox.expand()),
            ),
          ],
        ),
      ),
    );

    final edges = find.byKey(const Key('workspace_layer_leading_edge'));
    expect(edges, findsNWidgets(2));

    final painterTypes = tester
        .widgetList<CustomPaint>(edges)
        .map((paint) => paint.painter.runtimeType)
        .toSet();
    expect(painterTypes, hasLength(1));
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
