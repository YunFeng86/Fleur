import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../providers/query_providers.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/html_utils.dart';
import '../utils/timeago_locale.dart';
import 'favicon_circle.dart';

class ArticleListItem extends ConsumerWidget {
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

  static const double _metaWidth = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

    // Prefer description/contentHtml for the thumbnail
    final imageUrl = extractFirstImageSrc(article.contentHtml);
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? surfaces.cardSelected : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: surfaces.subtleDivider.withAlpha(72)),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          hoverColor: states.hoverTint,
          highlightColor: states.pressedTint,
          onTap: onTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      key: const Key('article_item_thumbnail'),
                      width: 72,
                      height: 54,
                      color: surfaces.floating,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Icon(
                          FleurIcons.brokenImage,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Feed Name ... [Fixed Width Meta]
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (feed != null &&
                                    ((feed.userTitle?.trim().isNotEmpty ==
                                            true) ||
                                        (feed.title?.trim().isNotEmpty ==
                                            true))) ...[
                                  // Feed Icon + Name
                                  FaviconCircle(
                                    siteUri: siteUri,
                                    diameter: 24,
                                    avatarSize: 16,
                                    fallbackIcon: FleurIcons.feed,
                                    fallbackColor: metaColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      key: const Key('article_item_feed_label'),
                                      (feed.userTitle?.trim().isNotEmpty ==
                                              true)
                                          ? feed.userTitle!
                                          : (feed.title ?? ''),
                                      style: metadataStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(
                            width: _metaWidth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Status Light (Unread Dot)
                                if (isUnread) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: theme.fleurState.unreadAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                // Time
                                Flexible(
                                  child: Text(
                                    key: const Key('article_item_timestamp'),
                                    timeStr,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: timestampStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Title
                      Text(
                        title.isEmpty ? article.link : title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Star Icon (if starred)
                      if (article.isStarred) ...[
                        const SizedBox(height: 4),
                        Icon(
                          FleurIcons.starActive,
                          size: 13,
                          color: states.savedAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
