import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../providers/query_providers.dart';
import '../theme/app_typography.dart';
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

  static const double _metaWidth = 96;

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

    return Card(
      elevation: 0,
      color: selected ? surfaces.cardSelected : surfaces.card,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: surfaces.subtleDivider),
      ),
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 60,
                    color: surfaces.floating,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Icon(
                        Icons.broken_image,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                  diameter: 28,
                                  avatarSize: 18,
                                  fallbackIcon: Icons.rss_feed,
                                  fallbackColor:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    (feed.userTitle?.trim().isNotEmpty == true)
                                        ? feed.userTitle!
                                        : (feed.title ?? ''),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight:
                                              AppTypography.platformWeight(
                                                FontWeight.w500,
                                              ),
                                        ),
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
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: theme.fleurState.unreadAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // Time
                              Flexible(
                                child: Text(
                                  timeStr,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppTypography.platformWeight(
                          isUnread ? FontWeight.w700 : FontWeight.w600,
                        ),
                        height: 1.2,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Star Icon (if starred)
                    if (article.isStarred) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.star, size: 14, color: states.savedAccent),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
