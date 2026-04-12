part of '../../widgets/reader_view.dart';

extension _ReaderSceneScaffold on _ReaderViewState {
  Widget _buildReaderSceneBody({
    required BuildContext context,
    required AppLocalizations l10n,
    required Article article,
    required ReaderSettings settings,
    required ArticleAiState aiState,
    required ThemeData sceneTheme,
    required FleurReaderTheme readerTokens,
  }) {
    final sceneStates = sceneTheme.fleurState;
    final hasExtracted = (article.extractedContentHtml ?? '').trim().isNotEmpty;
    final showExtracted =
        hasExtracted &&
        article.preferredContentView == ArticleContentView.extracted;
    final originalHtml =
        ((showExtracted ? article.extractedContentHtml : null) ??
                article.contentHtml ??
                '')
            .trim();
    final translatedHtml = (aiState.translationHtml ?? '').trim();
    final html = translatedHtml.isNotEmpty ? translatedHtml : originalHtml;

    final isChunked = html.length >= _ReaderViewState._chunkThreshold;
    _viewportCoordinator._handleViewportSizeChange(
      MediaQuery.sizeOf(context),
      isChunked: isChunked,
    );
    final title = article.title?.trim().isNotEmpty == true
        ? article.title!
        : l10n.reader;
    final dateStr = DateFormat(
      'yyyy/MM/dd HH:mm:ss',
    ).format(article.publishedAt.toLocal());

    final inlineHeader = _buildInlineHeader(
      context: context,
      l10n: l10n,
      title: title,
      dateText: dateStr,
      settings: settings,
      aiState: aiState,
      sceneTheme: sceneTheme,
      sceneStates: sceneStates,
      readerTokens: readerTokens,
    );

    final searchState = ref.watch(
      readerSearchControllerProvider(widget.articleId),
    );
    ref.listen<int>(
      readerSearchControllerProvider(
        widget.articleId,
      ).select((s) => s.navigationRequestId),
      (prev, next) {
        if (prev == next) return;
        final match = ref
            .read(readerSearchControllerProvider(widget.articleId))
            .currentMatch;
        if (match == null) return;
        _viewportCoordinator._scheduleScrollToSearchMatch(match);
      },
    );

    final displayChunks = html.isEmpty
        ? const <String>[]
        : isChunked
        ? (searchState.highlight?.highlightedChunks ??
              ReaderSearchService.splitHtmlIntoChunks(html))
        : (searchState.highlight?.highlightedChunks ?? <String>[html]);

    final contentWidget = html.isEmpty
        ? Center(child: Text(article.link, style: readerTokens.bodyStyle))
        : _viewportCoordinator._buildContentWidget(
            context,
            displayChunks,
            isChunked,
            article,
            settings,
            inlineHeader,
            searchState.currentAnchorId,
          );

    final bottomOverlay = _buildBottomOverlay(
      context: context,
      l10n: l10n,
      aiState: aiState,
      sceneTheme: sceneTheme,
      readerTokens: readerTokens,
      article: article,
      settings: settings,
    );

    final showAppBar = !isDesktop
        ? (!widget.embedded || widget.showBack)
        : widget.showBack;

    final body = _viewportCoordinator._wrapSearchShortcuts(
      child: Stack(
        fit: StackFit.expand,
        children: [
          contentWidget,
          ReaderSearchBar(
            key: _viewportCoordinator.searchBarKey,
            articleId: widget.articleId,
          ),
          bottomOverlay,
        ],
      ),
    );

    if (showAppBar) {
      return Theme(
        data: sceneTheme,
        child: Scaffold(
          appBar: AppBar(
            title: null,
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
                        context.go(widget.fallbackBackLocation);
                      }
                    },
                  )
                : null,
            actions: const [],
          ),
          body: body,
        ),
      );
    }

    return Theme(data: sceneTheme, child: body);
  }

  Widget _buildInlineHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required String title,
    required String dateText,
    required ReaderSettings settings,
    required ArticleAiState aiState,
    required ThemeData sceneTheme,
    required FleurStateTheme sceneStates,
    required FleurReaderTheme readerTokens,
  }) {
    final summaryText = (aiState.summaryText ?? '').trim();
    final showSummarySection =
        summaryText.isNotEmpty ||
        aiState.summaryStatus == ArticleAiTaskStatus.queued ||
        aiState.summaryStatus == ArticleAiTaskStatus.running ||
        aiState.summaryStatus == ArticleAiTaskStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: readerTokens.titleStyleForBodyFontSize(settings.fontSize),
        ),
        const SizedBox(height: 8),
        Text(dateText, style: readerTokens.metaStyle),
        if (showSummarySection) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: readerTokens.summarySurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.summarize_outlined,
                      size: 18,
                      color: sceneTheme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.aiSummaryAction,
                      style: sceneTheme.textTheme.labelLarge?.copyWith(
                        fontWeight: AppTypography.platformWeight(
                          FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (aiState.summaryStatus == ArticleAiTaskStatus.queued ||
                        aiState.summaryStatus == ArticleAiTaskStatus.running)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (aiState.summaryStatus == ArticleAiTaskStatus.error &&
                    (aiState.summaryError ?? '').trim().isNotEmpty)
                  Text(
                    aiState.summaryError!.trim(),
                    style: sceneTheme.textTheme.bodyMedium?.copyWith(
                      color: sceneStates.errorAccent,
                    ),
                  )
                else if (summaryText.isNotEmpty)
                  Text(summaryText, style: readerTokens.summaryStyle)
                else
                  Text(l10n.generating, style: readerTokens.summaryStyle),
                if (aiState.summaryOutdated) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.cachedPromptOutdated,
                          style: sceneTheme.textTheme.bodySmall?.copyWith(
                            color: sceneTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(
                          ref
                              .read(
                                articleAiControllerProvider(
                                  widget.articleId,
                                ).notifier,
                              )
                              .ensureSummary(force: true),
                        ),
                        child: Text(l10n.regenerate),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomOverlay({
    required BuildContext context,
    required AppLocalizations l10n,
    required ArticleAiState aiState,
    required ThemeData sceneTheme,
    required FleurReaderTheme readerTokens,
    required Article article,
    required ReaderSettings settings,
  }) {
    final languageBanner = _buildLanguageMismatchBanner(
      context: context,
      aiState: aiState,
      sceneTheme: sceneTheme,
      readerTokens: readerTokens,
    );
    final translationOutdatedBanner = _buildTranslationOutdatedBanner(
      context: context,
      l10n: l10n,
      aiState: aiState,
      sceneTheme: sceneTheme,
      readerTokens: readerTokens,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (languageBanner != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: readerTokens.maxWidth),
                child: languageBanner,
              ),
            ),
          if (translationOutdatedBanner != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: readerTokens.maxWidth),
                child: translationOutdatedBanner,
              ),
            ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: readerTokens.maxWidth),
              child: ReaderBottomBar(
                article: article,
                onShowSettings: () =>
                    _viewportCoordinator._showReaderSettings(settings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildLanguageMismatchBanner({
    required BuildContext context,
    required ArticleAiState aiState,
    required ThemeData sceneTheme,
    required FleurReaderTheme readerTokens,
  }) {
    if (!aiState.showLanguageMismatchBanner ||
        aiState.sourceLanguageTag == null) {
      return null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: readerTokens.bannerSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.languageMismatchBanner(
                localizedLanguageNameForTag(
                  Localizations.localeOf(context),
                  aiState.sourceLanguageTag!,
                ),
                localizedLanguageNameForTag(
                  Localizations.localeOf(context),
                  aiState.targetLanguageTag,
                ),
              ),
              style: sceneTheme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => unawaited(
              ref
                  .read(articleAiControllerProvider(widget.articleId).notifier)
                  .disableLanguageMismatchReminder(),
            ),
            child: Text(AppLocalizations.of(context)!.dontRemindThisLanguage),
          ),
        ],
      ),
    );
  }

  Widget? _buildTranslationOutdatedBanner({
    required BuildContext context,
    required AppLocalizations l10n,
    required ArticleAiState aiState,
    required ThemeData sceneTheme,
    required FleurReaderTheme readerTokens,
  }) {
    if (!aiState.translationOutdated || aiState.translationMode == null) {
      return null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: readerTokens.bannerSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.cachedPromptOutdated,
              style: sceneTheme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => unawaited(
              ref
                  .read(articleAiControllerProvider(widget.articleId).notifier)
                  .ensureTranslation(
                    mode: aiState.translationMode!,
                    force: true,
                  ),
            ),
            child: Text(l10n.regenerate),
          ),
        ],
      ),
    );
  }
}
