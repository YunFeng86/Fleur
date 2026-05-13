import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';
import '../../widgets/article_list.dart';
import '../../widgets/reader_view.dart';
import '../../widgets/sync_status_capsule.dart';

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

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final shadowColor = theme.shadowColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12,
    );

    return DecoratedBox(
      key: const Key('reading_pane_surface'),
      decoration: BoxDecoration(
        color: surfaces.reader,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: ColoredBox(color: surfaces.reader, child: child),
      ),
    );
  }
}
