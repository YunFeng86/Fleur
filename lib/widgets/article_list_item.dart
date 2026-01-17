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
  static const double _metaWidth = 104;

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

    return Card(
      elevation: selected ? 2 : 0,
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (feed?.title != null) ...[
                          Icon(
                            Icons.rss_feed,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
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
                    child: Text(
                      timeStr,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isUnread
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title.isEmpty ? article.link : title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                  color: isUnread
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (article.isStarred) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.star,
                  size: 16,
                  color: theme.colorScheme.tertiary,
                ),
              ],
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
