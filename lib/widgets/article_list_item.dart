import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../models/feed.dart';
import '../providers/query_providers.dart';
import '../providers/service_providers.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/html_utils.dart';
import '../utils/timeago_locale.dart';
import 'favicon_circle.dart';

class ArticleListItem extends ConsumerStatefulWidget {
  const ArticleListItem({
    super.key,
    required this.article,
    required this.selected,
    this.onTap,
    this.onSecondaryTapDown,
  });

  final Article article;
  final bool selected;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  ConsumerState<ArticleListItem> createState() => _ArticleListItemState();
}

class _ArticleListItemState extends ConsumerState<ArticleListItem> {
  static const _radius = BorderRadius.all(Radius.circular(8));
  static const double _headerHeight = 32;
  static const double _trailingWidth = 104;
  static const double _minImageLayoutWidth = 280;
  static const double _compactImageWidth = 128;
  static const double _compactImageHeight = 96;
  static const double _wideImageWidth = 156;
  static const double _wideImageHeight = 108;

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final isUnread = !article.isRead;
    final feedMap = ref.watch(feedMapProvider);
    final feed = feedMap[article.feedId];
    final siteUri = Uri.tryParse(
      (feed?.siteUrl?.trim().isNotEmpty == true)
          ? feed!.siteUrl!.trim()
          : article.link,
    );

    final title = (article.title ?? '').trim();
    final timeStr = timeago.format(
      article.publishedAt.toLocal(),
      locale: timeagoLocale(context),
    );

    final imageMetaStore = ref.watch(imageMetaStoreProvider);
    final imageUrl = extractPreviewImageSrc(
      article.contentHtml,
      metaLookup: (url) {
        final meta = imageMetaStore.peek(url);
        if (meta == null) return null;
        return PreviewImageSize(width: meta.width, height: meta.height);
      },
    );
    final previewText = extractPreviewText(article.contentHtml);
    final metaColor = theme.colorScheme.onSurfaceVariant;
    final metadataStyle = theme.textTheme.labelMedium?.copyWith(
      color: metaColor,
      fontSize: 11,
      fontWeight: AppTypography.platformWeight(FontWeight.w500),
      letterSpacing: 0,
      height: 1.1,
    );
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: metaColor,
      fontSize: 10,
      fontWeight: AppTypography.platformWeight(FontWeight.w500),
      letterSpacing: 0,
      height: 1.1,
    );
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: 0,
      height: 1.2,
      color: theme.colorScheme.onSurface,
    );
    final previewStyle = theme.textTheme.bodyMedium?.copyWith(
      color: metaColor,
      fontSize: 13,
      fontWeight: AppTypography.platformWeight(FontWeight.w400),
      letterSpacing: 0,
      height: 1.32,
    );
    final cardColor = widget.selected
        ? surfaces.cardSelected
        : Colors.transparent;
    final borderColor = widget.selected
        ? states.focusRing.withAlpha(78)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        child: Container(
          key: const Key('article_item_card'),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: _radius,
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                hoverColor: states.hoverTint,
                highlightColor: states.pressedTint,
                onHover: _setHovered,
                onTap: widget.onTap,
                onSecondaryTapDown: widget.onSecondaryTapDown,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _headerHeight,
                        child: Row(
                          children: [
                            FaviconCircle(
                              key: const Key('article_item_feed_icon'),
                              siteUri: siteUri,
                              diameter: _headerHeight,
                              avatarSize: 20,
                              fallbackIcon: FleurIcons.feed,
                              fallbackColor: metaColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                key: const Key('article_item_feed_label'),
                                _feedLabel(feed, article),
                                style: metadataStyle,
                                maxLines: 1,
                                softWrap: false,
                                overflow: _hovered
                                    ? TextOverflow.fade
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: _trailingWidth,
                              height: _headerHeight,
                              child: _hovered
                                  ? _ArticleItemActions(
                                      article: article,
                                      l10n: l10n,
                                      states: states,
                                      onToggleReadLater: _toggleReadLater,
                                      onToggleStar: _toggleStar,
                                      onToggleRead: _toggleRead,
                                    )
                                  : _ArticleItemTimestamp(
                                      isUnread: isUnread,
                                      timeStr: timeStr,
                                      style: timestampStyle,
                                      unreadColor: states.unreadAccent,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title.isEmpty ? article.link : title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (previewText.isNotEmpty || imageUrl != null) ...[
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final canShowImage =
                                imageUrl != null &&
                                constraints.maxWidth >= _minImageLayoutWidth;
                            final imageWidth = constraints.maxWidth >= 520
                                ? _wideImageWidth
                                : _compactImageWidth;
                            final imageHeight = constraints.maxWidth >= 520
                                ? _wideImageHeight
                                : _compactImageHeight;

                            final summary = previewText.isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    key: const Key('article_item_preview_text'),
                                    previewText,
                                    style: previewStyle,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  );

                            if (!canShowImage) return summary;

                            final image = _ArticlePreviewImage(
                              url: imageUrl,
                              width: imageWidth,
                              height: imageHeight,
                            );

                            if (previewText.isEmpty) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: image,
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: summary),
                                const SizedBox(width: 12),
                                image,
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  String _feedLabel(Feed? feed, Article article) {
    final userTitle = feed?.userTitle?.trim();
    if (userTitle != null && userTitle.isNotEmpty) return userTitle;
    final title = feed?.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final host = Uri.tryParse(article.link)?.host;
    return host == null || host.isEmpty ? article.link : host;
  }

  void _toggleReadLater() {
    unawaited(
      ref.read(articleActionServiceProvider).toggleReadLater(widget.article.id),
    );
  }

  void _toggleStar() {
    unawaited(
      ref.read(articleActionServiceProvider).toggleStar(widget.article.id),
    );
  }

  void _toggleRead() {
    final article = widget.article;
    unawaited(
      ref
          .read(articleActionServiceProvider)
          .markRead(article.id, !article.isRead),
    );
  }
}

class _ArticleItemTimestamp extends StatelessWidget {
  const _ArticleItemTimestamp({
    required this.isUnread,
    required this.timeStr,
    required this.style,
    required this.unreadColor,
  });

  final bool isUnread;
  final String timeStr;
  final TextStyle? style;
  final Color unreadColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isUnread) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: unreadColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            key: const Key('article_item_timestamp'),
            timeStr,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ArticleItemActions extends StatelessWidget {
  const _ArticleItemActions({
    required this.article,
    required this.l10n,
    required this.states,
    required this.onToggleReadLater,
    required this.onToggleStar,
    required this.onToggleRead,
  });

  final Article article;
  final AppLocalizations l10n;
  final FleurStateTheme states;
  final VoidCallback onToggleReadLater;
  final VoidCallback onToggleStar;
  final VoidCallback onToggleRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('article_item_hover_actions'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _ArticleItemActionButton(
          key: const Key('article_item_read_later_button'),
          tooltip: article.isReadLater ? l10n.removeReadLater : l10n.readLater,
          icon: article.isReadLater
              ? FleurIcons.readLaterActive
              : FleurIcons.readLater,
          color: article.isReadLater ? states.savedAccent : null,
          onPressed: onToggleReadLater,
        ),
        _ArticleItemActionButton(
          key: const Key('article_item_star_button'),
          tooltip: article.isStarred ? l10n.unstar : l10n.star,
          icon: article.isStarred ? FleurIcons.starActive : FleurIcons.star,
          color: article.isStarred ? states.savedAccent : null,
          onPressed: onToggleStar,
        ),
        _ArticleItemActionButton(
          key: const Key('article_item_read_button'),
          tooltip: article.isRead ? l10n.markUnread : l10n.markRead,
          icon: article.isRead ? FleurIcons.markUnread : FleurIcons.markRead,
          onPressed: onToggleRead,
        ),
      ],
    );
  }
}

class _ArticleItemActionButton extends StatelessWidget {
  const _ArticleItemActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? scheme.onSurfaceVariant),
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ArticlePreviewImage extends StatelessWidget {
  const _ArticlePreviewImage({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: const Key('article_item_thumbnail'),
        width: width,
        height: height,
        color: theme.fleurSurface.floating,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Icon(
            FleurIcons.brokenImage,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
