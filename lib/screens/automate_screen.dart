import 'package:flutter/material.dart';

import 'settings_screen.dart';

class AutomateScreen extends StatelessWidget {
  const AutomateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the Rules UI, but expose it as a top-level section.
    return const RulesTab();
  }
}
