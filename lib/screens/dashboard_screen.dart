import 'package:flutter/material.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import '../ui/global_nav.dart';
import '../utils/platform.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalWidth = MediaQuery.sizeOf(context).width;
    final useCompactTopBar =
        !isDesktop || globalNavModeForWidth(totalWidth) == GlobalNavMode.bottom;
    final content = Container(
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text('${l10n.dashboard} · ${l10n.comingSoon}'),
    );
    if (!useCompactTopBar) return content;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboard)),
      body: content,
    );
  }
}
