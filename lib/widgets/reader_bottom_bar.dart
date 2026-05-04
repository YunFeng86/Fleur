import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/repository_providers.dart';
import '../providers/query_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/service_providers.dart';
import '../providers/article_ai_providers.dart';
import '../models/article.dart';
import '../models/tag.dart';
import '../services/translation/article_translation.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../utils/tag_colors.dart';
import 'app_scrollbar.dart';
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
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final reader = theme.fleurReader;
    final aiState = ref.watch(articleAiControllerProvider(article.id));
    final aiController = ref.read(
      articleAiControllerProvider(article.id).notifier,
    );
    final fullTextController = ref.watch(fullTextControllerProvider);
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
    final isSummaryBusy =
        aiState.summaryStatus == ArticleAiTaskStatus.queued ||
        aiState.summaryStatus == ArticleAiTaskStatus.running;
    final hasSummary = (aiState.summaryText ?? '').trim().isNotEmpty;
    final isTranslationBusy =
        aiState.translationStatus == ArticleAiTaskStatus.queued ||
        aiState.translationStatus == ArticleAiTaskStatus.running;
    final hasTranslation = (aiState.translationHtml ?? '').trim().isNotEmpty;
    final hasFull = (article.extractedContentHtml ?? '').trim().isNotEmpty;
    final preferExtracted =
        article.preferredContentView == ArticleContentView.extracted;
    final showFull = hasFull && preferExtracted;
    final extractionFailed =
        !hasFull && article.contentSource == ContentSource.extractionFailed;

    Future<void> openTranslationSheet() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(l10n.translationMode)),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(l10n.immersiveTranslation),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(
                      aiController.ensureTranslation(
                        mode: ArticleTranslationMode.immersive,
                        force: aiState.translationOutdated,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate_outlined),
                  title: Text(l10n.traditionalTranslation),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(
                      aiController.ensureTranslation(
                        mode: ArticleTranslationMode.traditional,
                        force: aiState.translationOutdated,
                      ),
                    );
                  },
                ),
                if (hasTranslation)
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(l10n.clearTranslation),
                    onTap: () {
                      Navigator.of(context).pop();
                      aiController.clearTranslation();
                    },
                  ),
              ],
            ),
          );
        },
      );
    }

    Future<void> handleFullTextAction() async {
      if (fullTextController.isLoading) return;
      if (hasFull) {
        final next = showFull
            ? ArticleContentView.feed
            : ArticleContentView.extracted;
        await ref
            .read(articleRepositoryProvider)
            .setPreferredContentView(article.id, next);
        return;
      }
      final ok = await ref
          .read(fullTextControllerProvider.notifier)
          .fetch(article.id);
      if (!ok || !context.mounted) return;
      await ref
          .read(articleRepositoryProvider)
          .setPreferredContentView(article.id, ArticleContentView.extracted);
    }

    Future<void> handleOverflowAction(_ReaderOverflowAction action) async {
      switch (action) {
        case _ReaderOverflowAction.settings:
          onShowSettings();
          return;
        case _ReaderOverflowAction.summary:
          if (isSummaryBusy) return;
          await aiController.ensureSummary(force: aiState.summaryOutdated);
          return;
        case _ReaderOverflowAction.readLater:
          await ref
              .read(articleActionServiceProvider)
              .toggleReadLater(article.id);
          return;
        case _ReaderOverflowAction.tags:
          await _showManageTagsDialog(context, ref, article);
          return;
        case _ReaderOverflowAction.copyLink:
          await Clipboard.setData(ClipboardData(text: article.link));
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
          return;
        case _ReaderOverflowAction.share:
          final uri = Uri.tryParse(article.link);
          final subject = (article.title ?? '').trim().isEmpty
              ? null
              : article.title!.trim();
          await SharePlus.instance.share(
            uri == null
                ? ShareParams(text: article.link, subject: subject)
                : ShareParams(uri: uri, subject: subject),
          );
          return;
      }
    }

    final hasFeedInfo =
        feed != null && feedTitle != null && feedTitle.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: reader.toolbarSurface,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showFeedInfo = hasFeedInfo && constraints.maxWidth >= 360;

            return Row(
              children: [
                Expanded(
                  child: showFeedInfo
                      ? Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: surfaces.card,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: FaviconAvatar(
                                siteUri: siteUri,
                                size: 16,
                                fallbackIcon: Icons.rss_feed,
                                fallbackColor:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feedTitle,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: AppTypography.platformWeight(
                                    FontWeight.w700,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                if (showFeedInfo) const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('reader_translate_button'),
                      tooltip: l10n.translateAction,
                      onPressed: isTranslationBusy
                          ? null
                          : () => unawaited(openTranslationSheet()),
                      icon: isTranslationBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.translate,
                              color: hasTranslation ? states.syncAccent : null,
                            ),
                    ),
                    IconButton(
                      key: const Key('reader_full_text_button'),
                      tooltip: extractionFailed
                          ? l10n.fullTextRetry
                          : hasFull && showFull
                          ? l10n.collapse
                          : l10n.fullText,
                      onPressed: fullTextController.isLoading
                          ? null
                          : () => unawaited(handleFullTextAction()),
                      icon: fullTextController.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              extractionFailed
                                  ? Icons.refresh
                                  : Icons.chrome_reader_mode,
                              color: extractionFailed
                                  ? states.errorAccent
                                  : showFull
                                  ? states.syncAccent
                                  : null,
                            ),
                    ),
                    IconButton(
                      tooltip: article.isStarred ? l10n.unstar : l10n.star,
                      onPressed: () => ref
                          .read(articleActionServiceProvider)
                          .toggleStar(article.id),
                      icon: Icon(
                        article.isStarred ? Icons.star : Icons.star_border,
                        color: article.isStarred ? states.savedAccent : null,
                      ),
                    ),
                    IconButton(
                      tooltip: article.isRead ? l10n.markUnread : l10n.markRead,
                      onPressed: () => ref
                          .read(articleActionServiceProvider)
                          .markRead(article.id, !article.isRead),
                      icon: Icon(
                        article.isRead
                            ? Icons.mark_email_unread
                            : Icons.mark_email_read,
                      ),
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
                    PopupMenuButton<_ReaderOverflowAction>(
                      key: const Key('reader_more_actions_button'),
                      tooltip: l10n.more,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) {
                        unawaited(handleOverflowAction(value));
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_settings'),
                          value: _ReaderOverflowAction.settings,
                          child: ListTile(
                            leading: const Icon(Icons.text_fields),
                            title: Text(l10n.readerSettings),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_summary'),
                          value: _ReaderOverflowAction.summary,
                          enabled: !isSummaryBusy,
                          child: ListTile(
                            leading: isSummaryBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.summarize_outlined,
                                    color: hasSummary
                                        ? states.syncAccent
                                        : null,
                                  ),
                            title: Text(l10n.aiSummaryAction),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_read_later'),
                          value: _ReaderOverflowAction.readLater,
                          child: ListTile(
                            leading: Icon(
                              article.isReadLater
                                  ? Icons.watch_later
                                  : Icons.watch_later_outlined,
                              color: article.isReadLater
                                  ? states.savedAccent
                                  : null,
                            ),
                            title: Text(l10n.readLater),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_tags'),
                          value: _ReaderOverflowAction.tags,
                          child: ListTile(
                            leading: const Icon(Icons.label_outline),
                            title: Text(l10n.manageTags),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_copy_link'),
                          value: _ReaderOverflowAction.copyLink,
                          child: ListTile(
                            leading: const Icon(Icons.content_copy),
                            title: Text(l10n.copyLink),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<_ReaderOverflowAction>(
                          key: const Key('reader_overflow_share'),
                          value: _ReaderOverflowAction.share,
                          child: ListTile(
                            leading: const Icon(Icons.share_outlined),
                            title: Text(l10n.share),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showManageTagsDialog(
    BuildContext context,
    WidgetRef ref,
    Article article,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _TagsDialog(articleId: article.id);
      },
    );
  }
}

enum _ReaderOverflowAction {
  settings,
  summary,
  readLater,
  tags,
  copyLink,
  share,
}

class _TagsDialog extends ConsumerStatefulWidget {
  const _TagsDialog({required this.articleId});

  final int articleId;

  @override
  ConsumerState<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends ConsumerState<_TagsDialog> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedColor;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await ref.read(tagRepositoryProvider).create(name, color: _selectedColor);
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _selectedColor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allTagsAsync = ref.watch(tagsProvider);
    final articleTagsAsync = ref.watch(articleTagsProvider(widget.articleId));
    final tags = allTagsAsync.valueOrNull ?? const <Tag>[];
    final selected = articleTagsAsync.valueOrNull ?? const <Tag>[];
    final selectedIds = {for (final t in selected) t.id};
    final isLoading =
        (allTagsAsync.isLoading && tags.isEmpty) ||
        (articleTagsAsync.isLoading && selected.isEmpty);
    final hasError = allTagsAsync.hasError || articleTagsAsync.hasError;

    final articleRepo = ref.read(articleRepositoryProvider);
    final tagRepo = ref.read(tagRepositoryProvider);

    Future<void> toggleTag(Tag tag, bool nextSelected) async {
      try {
        if (nextSelected) {
          await articleRepo.addTag(widget.articleId, tag);
        } else {
          await articleRepo.removeTag(widget.articleId, tag);
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorMessage(e.toString()))),
        );
      }
    }

    Future<void> deleteTag(Tag tag) async {
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.deleteTagConfirmTitle),
              content: Text(l10n.deleteTagConfirmContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.delete),
                ),
              ],
            );
          },
        );
        if (ok != true) return;

        await tagRepo.delete(tag.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.deleted)));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorMessage(e.toString()))),
        );
      }
    }

    Widget listChild;
    if (hasError) {
      listChild = Center(child: Text(l10n.tagsLoadingError));
    } else if (isLoading) {
      listChild = const Center(child: CircularProgressIndicator());
    } else {
      listChild = AppScrollbar(
        controller: _scrollController,
        thumbVisibility: isDesktop,
        interactive: true,
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            final isSelected = selectedIds.contains(tag.id);
            return ListTile(
              leading: Icon(
                Icons.label,
                color: resolveTagColor(tag.name, tag.color),
              ),
              title: Text(tag.name),
              onTap: () => unawaited(toggleTag(tag, !isSelected)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => unawaited(deleteTag(tag)),
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      if (val == null) return;
                      unawaited(toggleTag(tag, val));
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return AlertDialog(
      title: Text(l10n.manageTags),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SizedBox(
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
                    final semanticLabel =
                        '${l10n.tagColor}: ${hex.toUpperCase()}';
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: semanticLabel,
                      child: Tooltip(
                        message: semanticLabel,
                        child: SizedBox.square(
                          dimension: 48,
                          child: InkResponse(
                            onTap: () {
                              setState(() => _selectedColor = hex);
                            },
                            containedInkWell: true,
                            highlightShape: BoxShape.circle,
                            radius: 24,
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: borderColor,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: checkColor,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: listChild),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
