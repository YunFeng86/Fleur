import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import 'reader_bottom_bar.dart';
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
  ProviderSubscription<AsyncValue<void>>? _fullTextSub;

  @override
  void initState() {
    super.initState();

    // Show extraction errors from the one-shot full text fetch.
    _fullTextSub = ref.listenManual<AsyncValue<void>>(
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
    var hasMarkedRead = false; // 追踪是否已标记
    _articleSub = ref.listenManual<AsyncValue<Article?>>(
      articleProvider(articleId),
      (prev, next) {
        final a = next.valueOrNull;

        // Auto-mark as read when entering/opening the reader for this article.
        // If the user explicitly toggles the article back to unread while
        // staying on this reader view, we do not immediately flip it back.
        if (!hasMarkedRead && a != null && !a.isRead) {
          final appSettings =
              ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
          if (appSettings.autoMarkRead) {
            ref.read(articleRepositoryProvider).markRead(articleId, true);
            hasMarkedRead = true;
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
  void dispose() {
    _articleSub?.close();
    _fullTextSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(articleProvider(widget.articleId));
    // final fullTextRequest = ref.watch(fullTextControllerProvider); // Unused
    final useFullText = ref.watch(
      fullTextViewEnabledProvider(widget.articleId),
    );
    final settingsAsync = ref.watch(readerSettingsProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
      ),
      data: (article) {
        final l10n = AppLocalizations.of(context)!;
        if (article == null) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            alignment: Alignment.center,
            child: Text(l10n.notFound),
          );
        }

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

        // Format date: e.g. "2026/1/14 08:00:00"
        final dateStr = DateFormat(
          'yyyy/MM/dd HH:mm:ss',
        ).format(article.publishedAt.toLocal());

        // New Inline Header
        final inlineHeader = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
          ],
        );

        final contentWidget = html.isEmpty
            ? Center(child: Text(article.link))
            : _buildContentWidget(
                context,
                html,
                article,
                settings,
                inlineHeader,
              );

        final bottomBar = Positioned(
          left: 0,
          right: 0, // Stretch full width
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ReaderView.maxReadingWidth,
              ),
              child: ReaderBottomBar(
                article: article,
                onShowSettings: () =>
                    _showReaderSettings(context, ref, settings),
              ),
            ),
          ),
        );

        // Show AppBar if we are not embedded (i.e. strictly full screen) OR if
        // we explicitly want a back button (e.g. secondary page on desktop).
        // On mobile (!isDesktop), we almost always want the scaffold if not embedded.
        final showAppBar = (!isDesktop && !widget.embedded) || widget.showBack;

        if (showAppBar) {
          return Scaffold(
            appBar: AppBar(
              title: null, // Title is inline
              automaticallyImplyLeading: true,
              leading: widget.showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    )
                  : null,
              actions: const [], // Actions moved to bottom bar
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [contentWidget, bottomBar],
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [contentWidget, bottomBar],
        );
      },
    );
  }

  Widget _buildContentWidget(
    BuildContext context,
    String html,
    Article article,
    ReaderSettings settings,
    Widget inlineHeader,
  ) {
    const chunkThreshold = 50000;
    if (html.length < chunkThreshold) {
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ReaderView.maxReadingWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                settings.horizontalPadding,
                24, // Top padding
                settings.horizontalPadding,
                100, // Bottom padding for floating bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  inlineHeader,
                  HtmlWidget(
                    html,
                    baseUrl: Uri.tryParse(article.link),
                    renderMode: RenderMode.column,
                    buildAsync: true,
                    onLoadingBuilder: (context, element, loadingProgress) =>
                        const SizedBox.shrink(),
                    textStyle: TextStyle(
                      fontSize: settings.fontSize,
                      height: settings.lineHeight,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onTapUrl: _onTapUrl,
                    onTapImage: _onTapImage,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Lazy load long articles
    final chunks = _splitHtmlIntoChunks(html);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ReaderView.maxReadingWidth),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            settings.horizontalPadding,
            24,
            settings.horizontalPadding,
            100,
          ),
          itemCount: chunks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return inlineHeader;
            return HtmlWidget(
              chunks[index - 1],
              baseUrl: Uri.tryParse(article.link),
              renderMode: RenderMode.column,
              buildAsync: true,
              onLoadingBuilder: (context, element, loadingProgress) =>
                  const SizedBox.shrink(),
              textStyle: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onTapUrl: _onTapUrl,
              onTapImage: _onTapImage,
            );
          },
        ),
      ),
    );
  }

  List<String> _splitHtmlIntoChunks(String html, {int chunkSize = 20000}) {
    final chunks = <String>[];
    int start = 0;
    // Regex to find closing block tags (case insensitive)
    final blockTagRe = RegExp(
      r'</(p|div|section|article|h[1-6]|ul|ol|table|blockquote)>',
      caseSensitive: false,
    );

    while (start < html.length) {
      if (start + chunkSize >= html.length) {
        chunks.add(html.substring(start));
        break;
      }

      int end = start + chunkSize;
      // Look for the next closing tag after the rough chunk boundary
      final match = blockTagRe.firstMatch(html.substring(end));
      if (match != null) {
        // Split after the closing tag
        end += match.end;
      } else {
        // Fallback: look for generic closing tag
        final closeIdx = html.indexOf('>', end);
        if (closeIdx != -1) {
          end = closeIdx + 1;
        }
        // If really no tags, use hard cut (unlikely for HTML)
      }

      chunks.add(html.substring(start, end));
      start = end;
    }
    return chunks;
  }

  Future<bool> _onTapUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onTapImage(ImageMetadata meta) {
    final src = meta.sources.isNotEmpty ? meta.sources.first.url : null;
    if (src == null || src.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(child: Image.network(src, fit: BoxFit.contain)),
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
