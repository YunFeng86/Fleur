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
  final List<String> _expectedLocations = <String>[];

  @override
  NavigationHistoryState build() {
    ref.onDispose(_unbindRouter);
    return NavigationHistoryState.empty;
  }

  void bindRouter(GoRouter router) {
    if (_router == router) {
      return;
    }

    _unbindRouter();
    _router = router;
    _routerListener = _handleRouteChanged;
    router.routerDelegate.addListener(_routerListener!);
    unawaited(
      Future<void>(() {
        if (_router == router) _recordCurrentRouterLocation();
      }),
    );
  }

  void visit(String location, {GoRouter? router}) {
    final target = _resolveRouter(router);
    if (target == null || location.isEmpty) return;
    if (state.currentLocation == location) return;

    final entries = <String>[...state.entries.take(state.index + 1), location];
    state = NavigationHistoryState(
      entries: List<String>.unmodifiable(entries),
      index: entries.length - 1,
    );
    _expect(location);
    target.go(location);
  }

  void replaceCurrent(String location, {GoRouter? router}) {
    final target = _resolveRouter(router);
    if (target == null || location.isEmpty) return;
    if (state.currentLocation == location) return;

    _replaceCurrentLocation(location);
    _expect(location);
    unawaited(target.replace(location));
  }

  Future<T?> push<T>(String location, {GoRouter? router, Object? extra}) {
    final target = _resolveRouter(router);
    if (target == null ||
        location.isEmpty ||
        state.currentLocation == location) {
      return Future<T?>.value();
    }

    final entries = <String>[...state.entries.take(state.index + 1), location];
    state = NavigationHistoryState(
      entries: List<String>.unmodifiable(entries),
      index: entries.length - 1,
    );
    _expect(location);
    return target.push<T>(location, extra: extra);
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
    state = state.copyWith(index: index);
    final router = _router;
    if (router == null) return;
    _expect(location);
    router.go(location);
  }

  void _handleRouteChanged() {
    _recordCurrentRouterLocation();
  }

  void _recordCurrentRouterLocation() {
    final router = _router;
    if (router == null) return;

    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;
    _recordLocation(configuration.uri.toString());
  }

  void _recordLocation(String location) {
    if (location.isEmpty) return;

    final expectedIndex = _expectedLocations.indexOf(location);
    if (expectedIndex >= 0) {
      _expectedLocations.removeRange(0, expectedIndex + 1);
      return;
    }

    if (_expectedLocations.isNotEmpty) {
      _expectedLocations.clear();
      _replaceCurrentLocation(location);
      return;
    }

    final currentLocation = state.currentLocation;
    if (currentLocation == location) {
      return;
    }

    final previousIndex = state.index - 1;
    if (previousIndex >= 0 && state.entries[previousIndex] == location) {
      state = state.copyWith(index: previousIndex);
      return;
    }

    final nextIndex = state.index + 1;
    if (nextIndex < state.entries.length &&
        state.entries[nextIndex] == location) {
      state = state.copyWith(index: nextIndex);
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

  GoRouter? _resolveRouter(GoRouter? router) {
    if (router != null && router != _router) bindRouter(router);
    return router ?? _router;
  }

  void _expect(String location) {
    _expectedLocations.add(location);
  }

  void _unbindRouter() {
    final router = _router;
    final listener = _routerListener;
    if (router != null && listener != null) {
      router.routerDelegate.removeListener(listener);
    }
    _router = null;
    _routerListener = null;
    _expectedLocations.clear();
  }
}
