import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/repository_providers.dart';
import '../providers/query_providers.dart';
import '../providers/reader_providers.dart';
import '../models/article.dart';

class ReaderBottomBar extends ConsumerWidget {
  const ReaderBottomBar({
    super.key,
    required this.article,
    required this.onShowSettings,
  });

  final Article article;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final feedMap = ref.watch(feedMapProvider);
    final feed = feedMap[article.feedId];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Feed Info
            if (feed != null) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    feed.title?.substring(0, 1).toUpperCase() ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feed.title ?? '',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),

            // Actions
            IconButton(
              tooltip: l10n.readerSettings,
              onPressed: onShowSettings,
              icon: const Icon(Icons.text_fields),
            ),
            IconButton(
              tooltip: article.isStarred ? l10n.unstar : l10n.star,
              onPressed: () => ref
                  .read(articleRepositoryProvider)
                  .toggleStar(article.id),
              icon: Icon(
                article.isStarred ? Icons.star : Icons.star_border,
                color: article.isStarred ? theme.colorScheme.tertiary : null,
              ),
            ),
            IconButton(
              tooltip: article.isRead ? l10n.markUnread : l10n.markRead,
              onPressed: () => ref
                  .read(articleRepositoryProvider)
                  .markRead(article.id, !article.isRead),
              icon: Icon(
                article.isRead
                    ? Icons.mark_email_unread
                    : Icons.mark_email_read,
              ),
            ),
             // Full Text / Reader Mode Toggle
             Consumer(
              builder: (context, ref, _) {
                final hasFull = (article.fullContentHtml ?? '').trim().isNotEmpty;
                final useFullText =
                    ref.watch(fullTextViewEnabledProvider(article.id));
                final controller = ref.watch(fullTextControllerProvider);
                final showFull = hasFull && useFullText;

                return IconButton(
                  tooltip: hasFull && showFull ? l10n.collapse : l10n.fullText,
                  onPressed: controller.isLoading
                      ? null
                      : hasFull
                          ? () {
                              ref
                                  .read(fullTextViewEnabledProvider(article.id)
                                      .notifier)
                                  .state = !useFullText;
                            }
                          : () {
                              // Fetch and show
                              ref
                                  .read(fullTextViewEnabledProvider(article.id)
                                      .notifier)
                                  .state = true;
                              ref
                                  .read(fullTextControllerProvider.notifier)
                                  .fetch(article.id);
                            },
                  icon: controller.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chrome_reader_mode,
                          color: showFull
                              ? theme.colorScheme.primary
                              : null,
                        ),
                );
              },
            ),
            IconButton(
              tooltip: 'Open in Browser', // TODO: Add l10n
              onPressed: () {
                final uri = Uri.tryParse(article.link);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
            ),
          ],
        ),
      ),
    );
  }
}
