import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';
import '../../widgets/article_list.dart';
import '../../widgets/reader_view.dart';
import '../../widgets/sync_status_capsule.dart';
import '../workspace_layers.dart';

class HomeArticleListPane extends StatelessWidget {
  const HomeArticleListPane({
    super.key,
    required this.selectedArticleId,
    required this.showSyncCapsule,
    this.width,
    this.heroTag,
    this.topBar,
  });

  final int? selectedArticleId;
  final bool showSyncCapsule;
  final double? width;
  final Object? heroTag;
  final Widget? topBar;

  @override
  Widget build(BuildContext context) {
    Widget child = SyncStatusCapsuleHost(
      enabled: showSyncCapsule,
      child: ArticleList(selectedArticleId: selectedArticleId, topBar: topBar),
    );

    if (width != null) {
      child = SizedBox(width: width, child: child);
    }
    if (heroTag != null) {
      child = Hero(
        tag: heroTag!,
        child: RepaintBoundary(child: child),
      );
    }
    return child;
  }
}

class HomeReaderPane extends StatelessWidget {
  const HomeReaderPane({
    super.key,
    required this.articleId,
    this.embedded = true,
  });

  final int articleId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ReadingPaneSurface(
      child: ReaderView(
        key: ValueKey('home-reader-$articleId'),
        articleId: articleId,
        embedded: embedded,
      ),
    );
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
      child: child,
    );
  }
}
