import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../providers/query_providers.dart';

class ArticleListItem extends ConsumerWidget {
  const ArticleListItem({
    super.key,
    required this.article,
    required this.selected,
    this.onTap,
  });

  final Article article;
  final bool selected;
  final VoidCallback? onTap;
  
  static const double _metaWidth = 96;
  
  // Use a simple regex to find the first img src
  // Parsing full HTML is expensive in a list view
  static final _imgSrcRegex = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
  
  String? _extractFirstImage(String? html) {
    if (html == null || html.isEmpty) return null;
    final match = _imgSrcRegex.firstMatch(html);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = !article.isRead;
    final feedMap = ref.watch(feedMapProvider);
    final feed = feedMap[article.feedId];

    final title = (article.title ?? '').trim();
    final timeStr = timeago.format(
      article.publishedAt.toLocal(),
      locale: _timeagoLocale(context),
    );

    // Prefer description/contentHtml for the thumbnail
    final imageUrl = _extractFirstImage(article.contentHtml);

    return Card(
      elevation: 0,
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
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
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
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
                              if (feed?.title != null) ...[
                                // Feed Icon + Name
                                Container(
                                   padding: const EdgeInsets.all(2),
                                   decoration: BoxDecoration(
                                     color: theme.colorScheme.surfaceContainer,
                                     shape: BoxShape.circle,
                                   ),
                                   child: Icon(
                                     Icons.rss_feed,
                                     size: 10,
                                     color: theme.colorScheme.onSurfaceVariant,
                                   ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    feed!.title!,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
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
                                    color: theme.colorScheme.primary, // Status Color
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
                        fontWeight: FontWeight.w500, // Always normal/medium weight
                        color: theme.colorScheme.onSurface, // Always standard color
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Star Icon (if starred)
                    if (article.isStarred) ...[
                      const SizedBox(height: 6),
                      Icon(
                        Icons.star,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
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

String _timeagoLocale(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'zh') {
    // Our app supports 'zh' (Simplified) and 'zh-Hant' (Traditional).
    final script = locale.scriptCode?.toLowerCase();
    if (script == 'hant') return 'zh';
    return 'zh_CN';
  }
  return 'en';
}
