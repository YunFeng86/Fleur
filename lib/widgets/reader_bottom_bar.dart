import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/repository_providers.dart';
import '../providers/query_providers.dart';
import '../providers/reader_providers.dart';
import '../models/article.dart';
import '../models/tag.dart';
import '../repositories/tag_repository.dart';
import '../utils/tag_colors.dart';
import 'favicon_avatar.dart';

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
    final feedTitleRaw = feed == null
        ? null
        : (feed.userTitle?.trim().isNotEmpty == true
              ? feed.userTitle!
              : feed.title);
    final feedTitle = feedTitleRaw?.trim();
    final siteUri = Uri.tryParse(
      (feed?.siteUrl?.trim().isNotEmpty == true)
          ? feed!.siteUrl!.trim()
          : article.link,
    );

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
        child: OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: [
            // Feed Info
            if (feed != null && feedTitle != null && feedTitle.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: FaviconAvatar(
                      siteUri: siteUri,
                      size: 16,
                      fallbackIcon: Icons.rss_feed,
                      fallbackColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      feedTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),

            // Actions
            Wrap(
              spacing: 4,
              children: [
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
                    color: article.isStarred
                        ? theme.colorScheme.tertiary
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: l10n.manageTags,
                  onPressed: () => _showManageTagsDialog(context, ref, article),
                  icon: const Icon(Icons.label_outline),
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
                IconButton(
                  tooltip: l10n.readLater,
                  onPressed: () => ref
                      .read(articleRepositoryProvider)
                      .toggleReadLater(article.id),
                  icon: Icon(
                    article.isReadLater
                        ? Icons.watch_later
                        : Icons.watch_later_outlined,
                    color: article.isReadLater
                        ? theme.colorScheme.tertiary
                        : null,
                  ),
                ),
                // 原文/提取切换
                Consumer(
                  builder: (context, ref, _) {
                    final useFullText = ref.watch(
                      fullTextViewEnabledProvider(article.id),
                    );
                    final controller = ref.watch(fullTextControllerProvider);
                    final hasFull = (article.extractedContentHtml ?? '')
                        .trim()
                        .isNotEmpty;
                    final showFull = hasFull && useFullText;

                    return IconButton(
                      tooltip: hasFull && showFull
                          ? l10n.collapse
                          : l10n.fullText,
                      onPressed: controller.isLoading
                          ? null
                          : hasFull
                          ? () async {
                              ref
                                      .read(
                                        fullTextViewEnabledProvider(
                                          article.id,
                                        ).notifier,
                                      )
                                      .state =
                                  !useFullText;
                            }
                          : () async {
                              // 先切换为提取视图，再触发提取。
                              ref
                                      .read(
                                        fullTextViewEnabledProvider(
                                          article.id,
                                        ).notifier,
                                      )
                                      .state =
                                  true;
                              await ref
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
                  tooltip: l10n.openInBrowser,
                  onPressed: () async {
                    final uri = Uri.tryParse(article.link);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageTagsDialog(
    BuildContext context,
    WidgetRef ref,
    Article article,
  ) async {
    // final l10n = AppLocalizations.of(context)!; // Unused
    final repo = ref.read(tagRepositoryProvider);
    final allTags = await repo.getAll();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _TagsDialog(article: article, initialTags: allTags, repo: repo);
      },
    );
  }
}

class _TagsDialog extends StatefulWidget {
  const _TagsDialog({
    required this.article,
    required this.initialTags,
    required this.repo,
  });

  final Article article;
  final List<Tag> initialTags;
  final TagRepository repo;

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  late List<Tag> _tags;
  final _controller = TextEditingController();
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _tags = List.of(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await widget.repo.create(name, color: _selectedColor);

    final updated = await widget.repo.getAll();
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _selectedColor = null;
      _tags = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // We need to listen to the article to see updated tags if we modify it.
    // But this dialog might not update live if we don't watch.
    // Actually, create tag updates _tags local state.
    // Toggling tag updates the article.
    // Let's use a Consumer to get the article repo.
    return Consumer(
      builder: (context, ref, _) {
        final articleRepo = ref.watch(articleRepositoryProvider);
        final currentArticle = ref.watch(articleProvider(widget.article.id));

        return AlertDialog(
          title: Text(l10n.manageTags),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: l10n.newTag,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _createTag(),
                      ),
                    ),
                    IconButton(
                      onPressed: _createTag,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.tagColor,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.autoColor),
                      selected: _selectedColor == null,
                      onSelected: (_) {
                        setState(() => _selectedColor = null);
                      },
                    ),
                    ...kTagColorPalette.map((hex) {
                      final color = tagColorFromHex(hex)!;
                      final selected = _selectedColor == hex;
                      final borderColor = selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor;
                      final checkColor = color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() => _selectedColor = hex);
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: selected
                              ? Icon(Icons.check, size: 16, color: checkColor)
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                currentArticle.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Text('Error loading article'),
                  data: (a) {
                    if (a == null) return const Text('Article not found');

                    // watchById does not auto-load links; ensure tags are loaded.
                    if (!a.tags.isLoaded) {
                      a.tags.loadSync();
                    }
                    final articleTags = a.tags.toList();
                    return Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _tags.length,
                        itemBuilder: (context, index) {
                          final tag = _tags[index];
                          final isSelected = articleTags.any(
                            (t) => t.id == tag.id,
                          );
                          return CheckboxListTile(
                            title: Text(tag.name),
                            value: isSelected,
                            onChanged: (val) async {
                              if (val == true) {
                                await articleRepo.addTag(a.id, tag);
                              } else {
                                await articleRepo.removeTag(a.id, tag);
                              }
                              // The articleProvider stream should update automatically, causing rebuild
                            },
                            secondary: Icon(
                              Icons.label,
                              color: resolveTagColor(tag.name, tag.color),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
  }
}
