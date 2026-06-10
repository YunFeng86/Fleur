import 'dart:ui';

import 'package:window_manager/window_manager.dart';

WindowOptions desktopWindowOptions() {
  const options = WindowOptions(
    size: Size(1200, 800),
    center: true,
    minimumSize: Size(420, 520),
    titleBarStyle: TitleBarStyle.hidden,
  );
  return options;
}
