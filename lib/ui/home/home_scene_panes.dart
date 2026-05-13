import 'package:flutter/material.dart';

import '../../theme/fleur_theme_extensions.dart';
import '../../theme/fleur_icons.dart';
import '../../widgets/article_list.dart';
import '../../widgets/fleur_empty_state.dart';
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
    required this.selectedArticleId,
    required this.placeholderText,
    required this.placeholderSubtitle,
    this.embedded = true,
  });

  final int? selectedArticleId;
  final String placeholderText;
  final String placeholderSubtitle;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final readerSurface = Theme.of(context).fleurSurface.reader;
    if (selectedArticleId == null) {
      return FleurEmptyState(
        variant: FleurEmptyStateVariant.reader,
        icon: FleurIcons.article,
        title: placeholderText,
        subtitle: placeholderSubtitle,
      );
    }
    return Container(
      color: readerSurface,
      child: ReaderView(
        key: ValueKey('home-reader-$selectedArticleId'),
        articleId: selectedArticleId!,
        embedded: embedded,
      ),
    );
  }
}
