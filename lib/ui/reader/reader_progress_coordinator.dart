part of '../../widgets/reader_view.dart';

final class _ReaderViewportCoordinator {
  _ReaderViewportCoordinator({
    required _ReaderViewState owner,
    required ReaderProgressStore progressStore,
    required _ReaderInteractionController interactionController,
  }) : _owner = owner,
       _progressStore = progressStore,
       _interactionController = interactionController;

  final _ReaderViewState _owner;
  final ReaderProgressStore _progressStore;
  final _ReaderInteractionController _interactionController;

  final ScrollController _scrollController = ScrollController();
  GlobalKey<HtmlWidgetState> _fullHtmlKey = GlobalKey<HtmlWidgetState>();
  final GlobalKey<ReaderSearchBarState> _searchBarKey =
      GlobalKey<ReaderSearchBarState>();
  final GlobalKey _listViewKey = GlobalKey();
  final Map<int, GlobalKey> _chunkKeys = {};
  final Map<int, GlobalKey<HtmlWidgetState>> _chunkHtmlKeys = {};
  final Map<int, String> _chunkHtmlSources = {};
  final Map<String, GlobalKey> _codeSearchAnchorKeys = {};
  final Set<int> _prefetchedChunks = <int>{};

  Timer? _progressSaveTimer;
  ReaderProgress? _pendingProgress;
  String? _currentContentHash;
  String? _resolvedContentHash;
  String? _hashSourceHtml;
  int _restoreAttempts = 0;
  bool _restoredScrollPosition = false;
  bool _isRestoring = false;
  Timer? _restoreTimer;
  int _searchScrollRequestId = 0;
  _ChunkAnchor? _pendingAnchor;
  _ChunkAnchor? _lastAnchor;
  Timer? _resizeTimer;
  bool _isResizing = false;
  int _resizeRestoreAttempts = 0;
  Size? _lastViewportSize;
  ReaderSettings? _lastViewportSettings;
  bool _usingChunkedLayout = false;
  Timer? _prefetchTimer;
  List<String>? _currentChunks;
  String? _fullHtmlSource;
  Uri? _currentImageBaseUrl;
  int? _pendingSaveArticleId;
  String? _pendingSaveContentHash;
  double? _pendingSavePixels;
  double? _pendingSaveProgress;
  int? _pendingSaveAnchorIndex;
  double? _pendingSaveAnchorFraction;
  double? _lastSavedPixels;
  double? _lastSavedProgress;

  WidgetRef get ref => _owner.ref;
  BuildContext get context => _owner.context;
  ReaderView get widget => _owner.widget;
  bool get mounted => _owner.mounted;
  ScrollController get scrollController => _scrollController;
  GlobalKey<ReaderSearchBarState> get searchBarKey => _searchBarKey;
  GlobalKey<SelectionAreaState> get _selectionAreaKey =>
      _interactionController.selectionAreaKey;

  void init() {
    _scrollController.addListener(_handleScroll);
  }

  void dispose() {
    flushPendingProgressSave();
    _restoreTimer?.cancel();
    _resizeTimer?.cancel();
    _prefetchTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
  }

  void resetState() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _pendingProgress = null;
    _currentContentHash = null;
    _resolvedContentHash = null;
    _hashSourceHtml = null;
    _restoredScrollPosition = false;
    _isRestoring = false;
    _isResizing = false;
    _pendingAnchor = null;
    _lastAnchor = null;
    _resizeRestoreAttempts = 0;
    _lastViewportSize = null;
    _lastViewportSettings = null;
    _usingChunkedLayout = false;
    _chunkKeys.clear();
    _chunkHtmlKeys.clear();
    _chunkHtmlSources.clear();
    _codeSearchAnchorKeys.clear();
    _prefetchedChunks.clear();
    _currentChunks = null;
    _fullHtmlKey = GlobalKey<HtmlWidgetState>();
    _fullHtmlSource = null;
    _currentImageBaseUrl = null;
    _restoreAttempts = 0;
    _pendingSaveArticleId = null;
    _pendingSaveContentHash = null;
    _pendingSavePixels = null;
    _pendingSaveProgress = null;
    _pendingSaveAnchorIndex = null;
    _pendingSaveAnchorFraction = null;
    _lastSavedPixels = null;
    _lastSavedProgress = null;
  }

  void flushPendingProgressSave() {
    if (_progressSaveTimer == null &&
        _pendingSavePixels == null &&
        _pendingSaveProgress == null) {
      return;
    }
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
    unawaited(_saveProgressNow());
  }

  void requestContentHashUpdate({required String html}) {
    final contentChanged = _hashSourceHtml != html;
    if (contentChanged) {
      _currentContentHash = null;
      _pendingProgress = null;
      _restoredScrollPosition = false;
      _restoreAttempts = 0;
      _resolvedContentHash = null;
    }

    if (!contentChanged && _resolvedContentHash != null) {
      _setResolvedContentHash(_resolvedContentHash!);
      return;
    }

    _hashSourceHtml = html;

    if (html.isEmpty) {
      _setResolvedContentHash('');
      return;
    }

    _setResolvedContentHash(ContentHash.compute(html));
  }

  void _setResolvedContentHash(String hash) {
    if (_resolvedContentHash == hash) {
      _syncProgressForContent(hash);
      return;
    }
    _resolvedContentHash = hash;
    _syncProgressForContent(hash);
  }

  void _syncProgressForContent(String contentHash) {
    if (_currentContentHash == contentHash) return;
    _currentContentHash = contentHash;
    _restoredScrollPosition = false;
    _restoreAttempts = 0;
    _pendingProgress = null;
    _prefetchedChunks.clear();
    _lastAnchor = null;
    if (contentHash.trim().isEmpty) {
      _scheduleRestore(contentHash);
      return;
    }
    unawaited(_loadProgressForContent(contentHash));
  }

  Future<void> _loadProgressForContent(String contentHash) async {
    final progress = await _progressStore.getProgress(
      articleId: widget.articleId,
      contentHash: contentHash,
    );
    if (!mounted) return;
    if (_currentContentHash != contentHash) return;
    _pendingProgress = progress;
    _scheduleRestore(contentHash);
  }

  void _scheduleRestore(String contentHash) {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryRestore(contentHash);
      });
    });
  }

  void _tryRestore(String contentHash) {
    if (!mounted) return;
    if (_restoredScrollPosition) return;
    if (_currentContentHash != contentHash) return;
    if (!_scrollController.hasClients) {
      _restoreAttempts++;
      if (_restoreAttempts < 4) {
        _scheduleRestore(contentHash);
      }
      return;
    }

    final position = _scrollController.position;
    final progress = _pendingProgress;
    if (progress == null || progress.contentHash != contentHash) {
      _restoredScrollPosition = true;
      if (position.pixels != position.minScrollExtent) {
        _scrollController.jumpTo(position.minScrollExtent);
      }
      return;
    }

    final maxExtent = position.maxScrollExtent;
    final minExtent = position.minScrollExtent;
    final targetPixels = progress.pixels;
    if (_canRestoreProgressAnchor(progress)) {
      if (_restoreProgressAnchor(progress)) {
        _restoredScrollPosition = true;
        return;
      }
      if (_restoreAttempts < 6) {
        _restoreAttempts++;
        _jumpNearProgressAnchor(progress);
        _scheduleRestore(contentHash);
        return;
      }
    }

    final needsMoreExtent = maxExtent <= 0 || targetPixels > maxExtent + 24;
    if (needsMoreExtent && _restoreAttempts < 6) {
      _restoreAttempts++;
      _scheduleRestore(contentHash);
      return;
    }

    final target = maxExtent > 0
        ? (targetPixels <= maxExtent + 8
              ? targetPixels
              : progress.progress * maxExtent)
        : targetPixels;
    final clamped = target
        .clamp(minExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - clamped).abs() > 1) {
      _isRestoring = true;
      _scrollController.jumpTo(clamped);
      _isRestoring = false;
    }
    _restoredScrollPosition = true;
  }

  void _handleScroll() {
    if (_isRestoring || _isResizing) return;
    if (!_scrollController.hasClients) return;
    final contentHash = _currentContentHash;
    if (contentHash == null || contentHash.trim().isEmpty) return;
    final position = _scrollController.position;
    if (!position.hasPixels) return;
    final maxExtent = position.maxScrollExtent;
    final pixels = position.pixels;
    final progress = maxExtent > 0
        ? (pixels / maxExtent).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final anchor = _findChunkAnchor();

    final lastPixels = _lastSavedPixels;
    final lastProgress = _lastSavedProgress;
    if (lastPixels != null && (pixels - lastPixels).abs() < 8) return;
    if (lastProgress != null && (progress - lastProgress).abs() < 0.005) {
      return;
    }

    _scheduleProgressSave(
      articleId: widget.articleId,
      contentHash: contentHash,
      pixels: pixels,
      progress: progress,
      anchor: anchor,
    );
    _maybePrefetchNextChunks();
  }

  void _scheduleProgressSave({
    required int articleId,
    required String contentHash,
    required double pixels,
    required double progress,
    _ChunkAnchor? anchor,
  }) {
    _pendingSaveArticleId = articleId;
    _pendingSaveContentHash = contentHash;
    _pendingSavePixels = pixels;
    _pendingSaveProgress = progress;
    _pendingSaveAnchorIndex = anchor?.index;
    _pendingSaveAnchorFraction = anchor?.fraction;
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveProgressNow());
    });
  }

  Future<void> _saveProgressNow() async {
    final articleId = _pendingSaveArticleId;
    final contentHash = _pendingSaveContentHash;
    final pixels = _pendingSavePixels;
    final progress = _pendingSaveProgress;
    final anchorIndex = _pendingSaveAnchorIndex;
    final anchorFraction = _pendingSaveAnchorFraction;
    if (articleId == null ||
        contentHash == null ||
        pixels == null ||
        progress == null) {
      return;
    }
    _pendingSaveArticleId = null;
    _pendingSaveContentHash = null;
    _pendingSavePixels = null;
    _pendingSaveProgress = null;
    _pendingSaveAnchorIndex = null;
    _pendingSaveAnchorFraction = null;

    final entry = ReaderProgress(
      articleId: articleId,
      contentHash: contentHash,
      pixels: pixels,
      progress: progress,
      updatedAt: DateTime.now(),
      anchorIndex: anchorIndex,
      anchorFraction: anchorFraction,
    );
    await _progressStore.saveProgress(entry);
    _lastSavedPixels = pixels;
    _lastSavedProgress = progress;
  }

  void _syncSearchDocumentHtml(int articleId) {
    final article = ref.read(articleProvider(articleId)).valueOrNull;
    if (article == null) return;
    final translatedHtml =
        (ref.read(articleAiControllerProvider(articleId)).translationHtml ?? '')
            .trim();
    final displayHtml = _selectSanitizedDisplayHtml(
      article: article,
      translationHtml: translatedHtml,
    );
    ref
        .read(readerSearchControllerProvider(articleId).notifier)
        .setDocumentHtml(displayHtml);
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    _interactionController._handleSelectionChanged(selection);
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    return _interactionController._buildContextMenu(
      context,
      selectableRegionState,
    );
  }

  Widget? _buildImageLoadingPlaceholder(
    BuildContext context,
    dom.Element element,
    double? loadingProgress,
  ) {
    return _interactionController._buildImageLoadingPlaceholder(
      context,
      element,
      loadingProgress,
    );
  }

  Widget? _buildImageErrorPlaceholder(
    BuildContext context,
    dom.Element element,
    dynamic error,
  ) {
    return _interactionController._buildImageErrorPlaceholder(
      context,
      element,
      error,
    );
  }

  Future<bool> _onTapUrl(String url) {
    return _interactionController._onTapUrl(url);
  }

  void _onTapImage(ImageMetadata meta) {
    _interactionController._onTapImage(meta);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _interactionController._handlePointerDown(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _interactionController._handlePointerMove(event);
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _interactionController._handlePointerHover(event);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _interactionController._handlePointerCancel(event);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    _interactionController._handlePointerSignal(event);
  }

  void _suppressContextMenuOnce() {
    _interactionController._suppressContextMenuOnce();
  }

  void _showFullContextMenu(Offset globalPosition) {
    _interactionController._showFullContextMenu(globalPosition);
  }

  Future<void> _showReaderSettings(ReaderSettings settings) {
    return _interactionController.showReaderSettings(settings);
  }

  String? _resolveImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('data:') ||
        trimmed.startsWith('file:') ||
        trimmed.startsWith('asset:')) {
      return null;
    }
    final base = _currentImageBaseUrl;
    if (base == null) return trimmed;
    return base.resolve(trimmed).toString();
  }
}
