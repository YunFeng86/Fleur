import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import '../models/article.dart';
import '../providers/app_settings_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';
import '../utils/platform.dart';
import '../ui/layout.dart';

class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({
    super.key,
    required this.articleId,
    this.embedded = false,
    this.showBack = false,
  });

  final int articleId;
  final bool embedded;
  final bool showBack;

  static const double maxReadingWidth = kMaxReadingWidth;

  @override
  ConsumerState<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends ConsumerState<ReaderView> {
  ProviderSubscription<AsyncValue<Article?>>? _articleSub;

  @override
  void initState() {
    super.initState();

    // Show extraction errors from the one-shot full text fetch.
    ref.listenManual<AsyncValue<void>>(
      fullTextControllerProvider,
      (prev, next) {
        if (!mounted) return;
        if (next.hasError) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fullTextFailed(next.error.toString()))),
          );
        }
      },
      fireImmediately: false,
    );

    _listenArticle(widget.articleId);
  }

  @override
  void didUpdateWidget(covariant ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _listenArticle(widget.articleId);
    }
  }

  void _listenArticle(int articleId) {
    _articleSub?.close();
    _articleSub = ref.listenManual<AsyncValue<Article?>>(
      articleProvider(articleId),
      (prev, next) {
        final a = next.valueOrNull;

        // Auto-mark as read when entering/opening the reader for this article.
        // If the user explicitly toggles the article back to unread while
        // staying on this reader view, we do not immediately flip it back.
        if (prev == null) {
          final appSettings =
              ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
          if (appSettings.autoMarkRead && a != null && !a.isRead) {
            ref.read(articleRepositoryProvider).markRead(articleId, true);
          }
        }

        // Prefetch images when content changes.
        final prevA = prev?.valueOrNull;
        final prevHtml = (prevA?.fullContentHtml ?? prevA?.contentHtml ?? '')
            .trim();
        final html = (a?.fullContentHtml ?? a?.contentHtml ?? '').trim();
        if (a == null || html.isEmpty) return;
        if (prevA != null && prevA.id == a.id && prevHtml == html) return;
        unawaited(
          ref
              .read(articleCacheServiceProvider)
              .prefetchImagesFromHtml(html, baseUrl: Uri.tryParse(a.link)),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(articleProvider(widget.articleId));
    final fullTextRequest = ref.watch(fullTextControllerProvider);
    final useFullText = ref.watch(fullTextViewEnabledProvider(widget.articleId));
    final settingsAsync = ref.watch(readerSettingsProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
      ),
      data: (article) {
        final l10n = AppLocalizations.of(context)!;
        if (article == null) return Center(child: Text(l10n.notFound));

        final settings = settingsAsync.valueOrNull ?? const ReaderSettings();
        final hasFull = (article.fullContentHtml ?? '').trim().isNotEmpty;
        final showFull = hasFull && useFullText;
        final html =
            ((showFull ? article.fullContentHtml : null) ??
                    article.contentHtml ??
                    '')
                .trim();
        final title = article.title?.trim().isNotEmpty == true
            ? article.title!
            : l10n.reader;

        final actions = <Widget>[
          IconButton(
            tooltip: hasFull && showFull ? l10n.collapse : l10n.fullText,
            onPressed: fullTextRequest.isLoading
                ? null
                : hasFull
                ? () {
                    final notifier = ref.read(
                      fullTextViewEnabledProvider(widget.articleId).notifier,
                    );
                    notifier.state = !notifier.state;
                  }
                : () {
                    // One click: start fetch and automatically show full text
                    // once it becomes available.
                    ref
                        .read(fullTextViewEnabledProvider(widget.articleId).notifier)
                        .state = true;
                    ref
                        .read(fullTextControllerProvider.notifier)
                        .fetch(widget.articleId);
                  },
            icon: fullTextRequest.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chrome_reader_mode,
                    color: hasFull && showFull
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
          ),
          IconButton(
            tooltip: l10n.readerSettings,
            onPressed: () => _showReaderSettings(context, ref, settings),
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            tooltip: article.isStarred ? l10n.unstar : l10n.star,
            onPressed: () =>
                ref.read(articleRepositoryProvider).toggleStar(widget.articleId),
            icon: Icon(article.isStarred ? Icons.star : Icons.star_border),
          ),
          IconButton(
            tooltip: article.isRead ? l10n.markUnread : l10n.markRead,
            onPressed: () => ref
                .read(articleRepositoryProvider)
                .markRead(widget.articleId, !article.isRead),
            icon: Icon(
              article.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
            ),
          ),
        ];

        final content = html.isEmpty
            ? Center(child: Text(article.link))
            : SingleChildScrollView(
                // Keep line-length readable even when the reader pane is wide.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ReaderView.maxReadingWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        settings.horizontalPadding,
                        12,
                        settings.horizontalPadding,
                        48,
                      ),
                      child: HtmlWidget(
                        html,
                        baseUrl: Uri.tryParse(article.link),
                        textStyle: TextStyle(
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onTapUrl: (url) async {
                          final uri = Uri.tryParse(url);
                          if (uri == null) return false;
                          return launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        onTapImage: (meta) {
                          final src =
                              meta.sources.isNotEmpty ? meta.sources.first.url : null;
                          if (src == null || src.trim().isEmpty) return;
                          showDialog<void>(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: Image.network(
                                        src,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );

        Widget header() {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  if (widget.showBack) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () {
                        final router = GoRouter.of(context);
                        if (router.canPop()) {
                          router.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ] else
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          );
        }

        if (!widget.embedded && !isDesktop) {
          return Scaffold(
            appBar: AppBar(title: Text(title), actions: actions),
            body: content,
          );
        }

        // Desktop always uses an in-content header so the window's top bar can
        // stay global and stable.
        if (!widget.embedded && isDesktop) {
          return Column(
            children: [
              header(),
              const Divider(height: 1),
              Expanded(child: content),
            ],
          );
        }

        // Embedded (2/3-column) reader.
        return Column(
          children: [
            header(),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Future<void> _showReaderSettings(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    Future<void> saveAndPop(ReaderSettings cur) async {
      await ref.read(readerSettingsProvider.notifier).save(cur);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    Widget buildContent(
      BuildContext context,
      ReaderSettings initial,
      EdgeInsets padding,
    ) {
      var cur = initial;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.readerSettings,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => saveAndPop(cur),
                        child: Text(l10n.done),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _slider(
                    label: l10n.fontSize,
                    value: cur.fontSize,
                    min: 12,
                    max: 28,
                    onChanged: (v) =>
                        setState(() => cur = cur.copyWith(fontSize: v)),
                  ),
                  _slider(
                    label: l10n.lineHeight,
                    value: cur.lineHeight,
                    min: 1.1,
                    max: 2.2,
                    onChanged: (v) =>
                        setState(() => cur = cur.copyWith(lineHeight: v)),
                  ),
                  _slider(
                    label: l10n.horizontalPadding,
                    value: cur.horizontalPadding,
                    min: 8,
                    max: 32,
                    onChanged: (v) => setState(
                      () => cur = cur.copyWith(horizontalPadding: v),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (isNarrow) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) {
          return buildContent(context, settings, const EdgeInsets.all(16));
        },
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: buildContent(context, settings, const EdgeInsets.all(16)),
          );
        },
      );
    }
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
