import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart' as flutter_math;
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/features/reader/application/article_ai_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/features/reader/application/reader_document_providers.dart';
import 'package:fleur/features/reader/application/reader_providers.dart';
import 'package:fleur/features/reader/application/reader_search_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/services/cache/image_meta_store.dart';
import 'package:fleur/services/reader_document/reader_document_handle.dart';
import 'package:fleur/services/reader_document/reader_document_models.dart';
import 'package:fleur/services/reader_html_normalizer.dart' as reader_html;
import 'package:fleur/services/reader_search_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_progress_store.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/app_drawer_scope.dart';
import 'package:fleur/ui/layout.dart';
import 'package:fleur/ui/motion.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/ui/workspace_layers.dart';
import 'package:fleur/utils/content_hash.dart';
import 'package:fleur/utils/language_utils.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/app_scrollbar.dart';
import 'package:fleur/widgets/fleur_empty_state.dart';
import 'package:go_router/go_router.dart';
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'code_rendering/reader_code_rendering.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_selectable_rich_text.dart';

part 'reader_view/reader_session_coordinator.dart';
part 'reader_view/reader_progress_coordinator.dart';
part 'reader_view/reader_chunk_coordinator.dart';
part 'reader_view/reader_interaction_controller.dart';
part 'reader_view/reader_scene_scaffold.dart';
part 'reader_view/reader_html_widget_factory.dart';
part 'reader_view/reader_media_widgets.dart';
part 'reader_view/reader_inert_controls.dart';
part 'reader_view/reader_code_block.dart';
part 'reader_view/reader_math_node.dart';

class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({
    super.key,
    required this.articleId,
    this.embedded = false,
    this.showBack = false,
    this.fallbackBackLocation = '/',
  });

  final int articleId;
  final bool embedded;
  final bool showBack;
  final String fallbackBackLocation;

  static const double maxReadingWidth = kMaxReadingWidth;

  @override
  ConsumerState<ReaderView> createState() => _ReaderViewState();
}

class _ToggleReaderSearchIntent extends Intent {
  const _ToggleReaderSearchIntent();
}

class _CloseReaderSearchIntent extends Intent {
  const _CloseReaderSearchIntent();
}

class _ReaderViewState extends ConsumerState<ReaderView> {
  ProviderSubscription<AsyncValue<void>>? _fullTextSub;
  late final _ReaderInteractionController _interactionController;
  late final _ReaderViewportCoordinator _viewportCoordinator;
  late final _ReaderSessionCoordinator _sessionCoordinator;
  ReaderDocumentHandle? _lastScheduledSearchDocumentHandle;
  ReaderDocumentKey? _lastScheduledSearchDocumentKey;
  bool _searchDocumentSyncScheduled = false;
  static const double _autoScrollDeadZone = 6;
  static const double _autoScrollSpeedFactor = 0.12;

  @override
  void initState() {
    super.initState();
    _interactionController = _ReaderInteractionController(
      owner: this,
      imageMetaStore: ref.read(imageMetaStoreProvider),
    );
    _viewportCoordinator = _ReaderViewportCoordinator(
      owner: this,
      progressStore: ref.read(readerProgressStoreProvider),
      interactionController: _interactionController,
    );
    _interactionController.attachViewport(_viewportCoordinator);
    _sessionCoordinator = _ReaderSessionCoordinator(owner: this);
    _interactionController.prime();
    _viewportCoordinator.init();

    // Show extraction errors from the one-shot full text fetch.
    _fullTextSub = ref.listenManual<AsyncValue<void>>(
      fullTextControllerProvider,
      (prev, next) {
        if (!mounted) return;
        if (next.hasError) {
          final l10n = AppLocalizations.of(context)!;
          final error = next.error;
          if (error == null) return;

          String message;
          if (error is ArticleExtractionException) {
            switch (error.type) {
              case ArticleExtractionErrorType.emptyContent:
                message = l10n.fullTextRetry;
            }
          } else {
            message = l10n.fullTextFailed(error.toString());
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      fireImmediately: false,
    );

    _sessionCoordinator.listenArticle(widget.articleId);
    _sessionCoordinator.listenTranslationHtml(widget.articleId);
  }

  @override
  void didUpdateWidget(covariant ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _viewportCoordinator.flushPendingProgressSave();
      _viewportCoordinator.resetState();
      if (_viewportCoordinator.scrollController.hasClients) {
        _viewportCoordinator.scrollController.jumpTo(
          _viewportCoordinator.scrollController.position.minScrollExtent,
        );
      }
      _sessionCoordinator.listenArticle(widget.articleId);
      _sessionCoordinator.listenTranslationHtml(widget.articleId);
    }
  }

  @override
  void dispose() {
    _viewportCoordinator.dispose();
    _sessionCoordinator.dispose();
    _interactionController.dispose();
    _fullTextSub?.close();
    super.dispose();
  }

  void _scheduleSearchDocumentSync(ReaderDocumentHandle handle) {
    final key = handle.snapshot.documentKey;
    if (_lastScheduledSearchDocumentKey == key &&
        identical(_lastScheduledSearchDocumentHandle, handle)) {
      return;
    }
    _lastScheduledSearchDocumentKey = key;
    _lastScheduledSearchDocumentHandle = handle;
    if (_searchDocumentSyncScheduled) return;
    _searchDocumentSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchDocumentSyncScheduled = false;
      if (!mounted) return;
      final nextHandle = _lastScheduledSearchDocumentHandle;
      if (nextHandle == null) return;
      ref
          .read(readerSearchControllerProvider(widget.articleId).notifier)
          .setDocumentHandle(nextHandle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(articleProvider(widget.articleId));
    // final fullTextRequest = ref.watch(fullTextControllerProvider); // Unused
    final settingsAsync = ref.watch(readerSettingsProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
      ),
      data: (article) {
        final l10n = AppLocalizations.of(context)!;
        final baseTheme = Theme.of(context);
        final settings = settingsAsync.valueOrNull ?? const ReaderSettings();
        final sceneTheme = AppTheme.readerScene(baseTheme, settings: settings);
        final readerTokens = sceneTheme.fleurReader;
        if (article == null) {
          return FleurEmptyState(
            variant: FleurEmptyStateVariant.reader,
            icon: FleurIcons.article,
            title: l10n.notFound,
            subtitle: l10n.articleNotFoundSubtitle,
          );
        }

        final aiState = ref.watch(
          articleAiControllerProvider(widget.articleId),
        );
        return _buildReaderSceneBody(
          context: context,
          l10n: l10n,
          article: article,
          settings: settings,
          aiState: aiState,
          sceneTheme: sceneTheme,
          readerTokens: readerTokens,
        );
      },
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _ChunkAnchor {
  const _ChunkAnchor({required this.index, required this.fraction});

  final int index;
  final double fraction;
}

@visibleForTesting
String normalizeReaderHtmlForDisplay(String html) {
  return reader_html.normalizeReaderHtmlForDisplay(html);
}
