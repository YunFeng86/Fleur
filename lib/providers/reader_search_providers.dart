import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reader_document/reader_document_handle.dart';
import '../services/reader_document/reader_document_models.dart';
import '../services/reader_document/reader_document_pipeline.dart';
import '../services/reader_search_service.dart';

final readerSearchServiceProvider = Provider<ReaderSearchService>((ref) {
  return ReaderSearchService();
});

@immutable
class ReaderSearchState {
  static const Object _unset = Object();

  const ReaderSearchState({
    required this.visible,
    required this.query,
    required this.caseSensitive,
    required this.highlight,
    required this.currentMatchIndex,
    required this.isSearching,
    required this.navigationRequestId,
  });

  const ReaderSearchState.initial()
    : visible = false,
      query = '',
      caseSensitive = false,
      highlight = null,
      currentMatchIndex = 0,
      isSearching = false,
      navigationRequestId = 0;

  final bool visible;
  final String query;
  final bool caseSensitive;
  final ReaderSearchHighlight? highlight;
  final int currentMatchIndex;
  final bool isSearching;

  /// Increments when the UI should scroll to current match.
  final int navigationRequestId;

  int get totalMatches => highlight?.matches.length ?? 0;

  int get currentMatchNumber {
    final total = totalMatches;
    if (total <= 0) return 0;
    final clamped = currentMatchIndex.clamp(0, total - 1);
    return clamped + 1;
  }

  ReaderSearchMatch? get currentMatch {
    final h = highlight;
    if (h == null) return null;
    if (h.matches.isEmpty) return null;
    final total = h.matches.length;
    final idx = currentMatchIndex.clamp(0, total - 1);
    return h.matches[idx];
  }

  String? get currentAnchorId => currentMatch?.anchorId;

  ReaderSearchState copyWith({
    bool? visible,
    String? query,
    bool? caseSensitive,
    Object? highlight = _unset,
    int? currentMatchIndex,
    bool? isSearching,
    int? navigationRequestId,
  }) {
    return ReaderSearchState(
      visible: visible ?? this.visible,
      query: query ?? this.query,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      highlight: identical(highlight, _unset)
          ? this.highlight
          : highlight as ReaderSearchHighlight?,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
      isSearching: isSearching ?? this.isSearching,
      navigationRequestId: navigationRequestId ?? this.navigationRequestId,
    );
  }
}

final readerSearchControllerProvider =
    AutoDisposeNotifierProviderFamily<
      ReaderSearchController,
      ReaderSearchState,
      int
    >(ReaderSearchController.new);

class ReaderSearchController
    extends AutoDisposeFamilyNotifier<ReaderSearchState, int> {
  Timer? _debounce;
  int _requestId = 0;
  int _documentRevision = 0;
  ReaderDocumentHandle? _documentHandle;
  ReaderDocumentKey? _documentKey;
  String _fallbackHtml = '';

  ReaderSearchService get _service => ref.read(readerSearchServiceProvider);

  @override
  ReaderSearchState build(int articleId) {
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
      _requestId++;
      _documentHandle?.releaseTransientSearchArtifacts();
      _documentHandle = null;
      _documentKey = null;
    });
    return const ReaderSearchState.initial();
  }

  void setDocumentHandle(ReaderDocumentHandle handle) {
    final key = handle.snapshot.documentKey;
    final sameDocument =
        _documentKey == key && identical(_documentHandle, handle);
    if (sameDocument) return;
    _documentHandle?.releaseTransientSearchArtifacts();
    _documentHandle = handle;
    _documentKey = key;
    _fallbackHtml = '';
    _documentRevision++;
    state = state.copyWith(highlight: null, currentMatchIndex: 0);
    if (state.visible && state.query.trim().isNotEmpty) {
      _scheduleSearch(immediate: true);
    }
  }

  void setDocumentHtml(String html) {
    if (_documentHandle == null && html == _fallbackHtml) return;
    _documentHandle?.releaseTransientSearchArtifacts();
    _documentHandle = null;
    _documentKey = null;
    _fallbackHtml = html;
    _documentRevision++;
    state = state.copyWith(highlight: null, currentMatchIndex: 0);
    if (state.visible && state.query.trim().isNotEmpty) {
      _scheduleSearch(immediate: true);
    }
  }

  void toggleVisible() {
    if (state.visible) {
      close(clearQuery: true);
    } else {
      open();
    }
  }

  void open() {
    if (state.visible) return;
    state = state.copyWith(visible: true);
    if (state.query.trim().isNotEmpty) {
      _scheduleSearch(immediate: true);
    }
  }

  void close({required bool clearQuery}) {
    if (!state.visible && !clearQuery) return;
    _debounce?.cancel();
    _debounce = null;
    _requestId++;
    if (clearQuery) {
      _documentHandle?.releaseTransientSearchArtifacts();
    }
    state = state.copyWith(
      visible: false,
      query: clearQuery ? '' : state.query,
      highlight: clearQuery ? null : state.highlight,
      currentMatchIndex: 0,
      isSearching: false,
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query, currentMatchIndex: 0);
    _scheduleSearch();
  }

  void toggleCaseSensitive() {
    state = state.copyWith(caseSensitive: !state.caseSensitive);
    _scheduleSearch(immediate: true);
  }

  void nextMatch() {
    final total = state.totalMatches;
    if (total <= 0) return;
    final next = (state.currentMatchIndex + 1) % total;
    state = state.copyWith(
      currentMatchIndex: next,
      navigationRequestId: state.navigationRequestId + 1,
    );
  }

  void previousMatch() {
    final total = state.totalMatches;
    if (total <= 0) return;
    final prev = (state.currentMatchIndex - 1) % total;
    state = state.copyWith(
      currentMatchIndex: prev,
      navigationRequestId: state.navigationRequestId + 1,
    );
  }

  void _scheduleSearch({bool immediate = false}) {
    if (!state.visible) return;
    _debounce?.cancel();
    _debounce = null;

    if (immediate) {
      _runSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _debounce = null;
      _runSearch();
    });
  }

  void _runSearch() {
    final query = state.query.trim();
    if (query.isEmpty) {
      _documentHandle?.releaseTransientSearchArtifacts();
      state = state.copyWith(
        highlight: null,
        currentMatchIndex: 0,
        isSearching: false,
      );
      return;
    }
    final chunks = _materializeSearchChunks();
    if (chunks.isEmpty) {
      state = state.copyWith(
        highlight: null,
        currentMatchIndex: 0,
        isSearching: false,
      );
      return;
    }

    final requestId = ++_requestId;
    final docRevision = _documentRevision;
    state = state.copyWith(isSearching: true);

    unawaited(() async {
      final highlight = await _service.highlightChunks(
        chunks: chunks,
        query: query,
        caseSensitive: state.caseSensitive,
        anchorPrefix: 'rs-$arg-',
      );
      if (requestId != _requestId) return;
      if (docRevision != _documentRevision) return;

      final total = highlight.matches.length;
      state = state.copyWith(
        highlight: highlight,
        isSearching: false,
        currentMatchIndex: 0,
        navigationRequestId: total > 0
            ? state.navigationRequestId + 1
            : state.navigationRequestId,
      );
    }());
  }

  List<String> _materializeSearchChunks() {
    final handle = _documentHandle;
    if (handle != null) {
      final snapshot = handle.snapshot;
      if (snapshot.displayHtml.isEmpty) return const <String>[];
      if (!snapshot.isChunked) return <String>[snapshot.displayHtml];
      return handle.materializeRanges(snapshot.chunks);
    }

    final html = _fallbackHtml;
    if (html.isEmpty) return const <String>[];
    if (html.length < ReaderSearchService.chunkThreshold) return <String>[html];
    final ranges = ReaderDocumentPipeline.splitHtmlIntoRanges(html);
    return [for (final range in ranges) html.substring(range.start, range.end)];
  }
}
