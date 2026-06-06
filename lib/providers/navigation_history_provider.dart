import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NavigationHistoryState {
  const NavigationHistoryState({required this.entries, required this.index});

  static const empty = NavigationHistoryState(entries: <String>[], index: -1);

  final List<String> entries;
  final int index;

  bool get canGoBack => index > 0 && index < entries.length;
  bool get canGoForward => index >= 0 && index + 1 < entries.length;

  String? get currentLocation {
    if (index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  NavigationHistoryState copyWith({List<String>? entries, int? index}) {
    return NavigationHistoryState(
      entries: entries ?? this.entries,
      index: index ?? this.index,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NavigationHistoryState &&
        listEquals(other.entries, entries) &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(entries), index);
}

final navigationHistoryControllerProvider =
    NotifierProvider<NavigationHistoryController, NavigationHistoryState>(
      NavigationHistoryController.new,
    );

class NavigationHistoryController extends Notifier<NavigationHistoryState> {
  GoRouter? _router;
  VoidCallback? _routerListener;
  bool _replaceNextNavigation = false;
  bool _recordScheduled = false;
  String? _pendingLocation;
  String? _replayingLocation;

  @override
  NavigationHistoryState build() {
    ref.onDispose(_unbindRouter);
    return NavigationHistoryState.empty;
  }

  void bindRouter(GoRouter router) {
    if (_router == router) {
      _scheduleCurrentRouterLocationRecord();
      return;
    }

    _unbindRouter();
    _router = router;
    _routerListener = _handleRouteChanged;
    router.routerDelegate.addListener(_routerListener!);
    _scheduleCurrentRouterLocationRecord();
  }

  void markNextNavigationAsReplacement() {
    _replaceNextNavigation = true;
  }

  void goBack() {
    if (!state.canGoBack) return;
    _goToHistoryIndex(state.index - 1);
  }

  void goForward() {
    if (!state.canGoForward) return;
    _goToHistoryIndex(state.index + 1);
  }

  void _goToHistoryIndex(int index) {
    if (index < 0 || index >= state.entries.length) return;
    final location = state.entries[index];
    _replaceNextNavigation = false;
    _replayingLocation = location;
    state = state.copyWith(index: index);
    _router?.go(location);
  }

  void _handleRouteChanged() {
    _scheduleCurrentRouterLocationRecord();
  }

  void _scheduleCurrentRouterLocationRecord() {
    final router = _router;
    if (router == null) return;

    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;
    _pendingLocation = configuration.uri.toString();
    if (_recordScheduled) return;

    _recordScheduled = true;
    unawaited(
      Future<void>(() {
        _recordScheduled = false;
        if (_router == null) return;
        final location = _pendingLocation;
        _pendingLocation = null;
        if (location == null) return;
        _recordLocation(location);
      }),
    );
  }

  void _recordLocation(String location) {
    if (location.isEmpty) return;

    final replayingLocation = _replayingLocation;
    if (replayingLocation == location) {
      _replayingLocation = null;
      return;
    }

    final currentLocation = state.currentLocation;
    if (currentLocation == location) {
      _replaceNextNavigation = false;
      return;
    }

    final previousIndex = state.index - 1;
    if (previousIndex >= 0 && state.entries[previousIndex] == location) {
      _replaceNextNavigation = false;
      state = state.copyWith(index: previousIndex);
      return;
    }

    final nextIndex = state.index + 1;
    if (nextIndex < state.entries.length &&
        state.entries[nextIndex] == location) {
      _replaceNextNavigation = false;
      state = state.copyWith(index: nextIndex);
      return;
    }

    if (_replaceNextNavigation) {
      _replaceNextNavigation = false;
      _replaceCurrentLocation(location);
      return;
    }

    final entries = <String>[...state.entries.take(state.index + 1), location];
    state = NavigationHistoryState(
      entries: List<String>.unmodifiable(entries),
      index: entries.length - 1,
    );
  }

  void _replaceCurrentLocation(String location) {
    if (state.index < 0 || state.entries.isEmpty) {
      state = NavigationHistoryState(
        entries: List<String>.unmodifiable(<String>[location]),
        index: 0,
      );
      return;
    }

    if (state.index > 0 && state.entries[state.index - 1] == location) {
      final entries = state.entries.take(state.index).toList();
      state = NavigationHistoryState(
        entries: List<String>.unmodifiable(entries),
        index: entries.length - 1,
      );
      return;
    }

    final entries = state.entries.take(state.index + 1).toList();
    entries[state.index] = location;
    state = NavigationHistoryState(
      entries: List<String>.unmodifiable(entries),
      index: state.index,
    );
  }

  void _unbindRouter() {
    final router = _router;
    final listener = _routerListener;
    if (router != null && listener != null) {
      router.routerDelegate.removeListener(listener);
    }
    _router = null;
    _routerListener = null;
    _replaceNextNavigation = false;
    _recordScheduled = false;
    _pendingLocation = null;
    _replayingLocation = null;
  }
}
