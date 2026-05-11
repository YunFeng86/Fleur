import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/context_menu_position.dart';

void main() {
  testWidgets('contextMenuPositionForGlobalPoint anchors to overlay point', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: SizedBox.expand(key: key)));

    final position = contextMenuPositionForGlobalPoint(
      key.currentContext!,
      const Offset(123, 234),
    );

    expect(position.left, 123);
    expect(position.top, 234);
    expect(position.right, 800 - 123);
    expect(position.bottom, 600 - 234);
  });
}
