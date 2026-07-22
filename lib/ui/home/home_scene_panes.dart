import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';
import '../../widgets/article_list.dart';
import '../../features/reader/reader.dart';
import '../../widgets/sync_status_capsule.dart';
import '../workspace_layers.dart';

class HomeArticleListPane extends StatelessWidget {
  const HomeArticleListPane({
    super.key,
    required this.selectedArticleId,
    required this.showSyncCapsule,
    this.topBar,
  });

  final int? selectedArticleId;
  final bool showSyncCapsule;
  final Widget? topBar;

  @override
  Widget build(BuildContext context) {
    return SyncStatusCapsuleHost(
      enabled: showSyncCapsule,
      child: ArticleList(selectedArticleId: selectedArticleId, topBar: topBar),
    );
  }
}

class HomeReaderPane extends StatelessWidget {
  const HomeReaderPane({
    super.key,
    required this.articleId,
    this.embedded = true,
    this.fallbackBackLocation = '/',
  });

  final int articleId;
  final bool embedded;
  final String fallbackBackLocation;

  @override
  Widget build(BuildContext context) {
    final reader = ReaderView(
      key: ValueKey('home-reader-$articleId'),
      articleId: articleId,
      embedded: embedded,
      showBack: !embedded,
      fallbackBackLocation: fallbackBackLocation,
    );
    if (!embedded) return reader;
    return ReadingPaneSurface(child: reader);
  }
}

class ReadingPaneSurface extends StatelessWidget {
  const ReadingPaneSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WorkspaceLayerSurface(
      key: const Key('reading_pane_surface'),
      color: Theme.of(context).fleurSurface.reader,
      leadingEdge: WorkspaceLayerEdge.level2,
      child: child,
    );
  }
}
