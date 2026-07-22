import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/article_scope.dart';
import '../../providers/query_providers.dart';
import 'home_screen.dart';

class ReadingWorkspaceScreen extends ConsumerStatefulWidget {
  const ReadingWorkspaceScreen({
    super.key,
    required this.scope,
    required this.selectedArticleId,
  });

  final ArticleScope scope;
  final int? selectedArticleId;

  @override
  ConsumerState<ReadingWorkspaceScreen> createState() =>
      _ReadingWorkspaceScreenState();
}

class _ReadingWorkspaceScreenState
    extends ConsumerState<ReadingWorkspaceScreen> {
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleScopeSync();
  }

  @override
  void didUpdateWidget(covariant ReadingWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) _scheduleScopeSync();
  }

  void _scheduleScopeSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      final filter = ref.read(articleListFilterProvider);
      if (_isSynced(filter)) return;
      ref
          .read(articleListFilterProvider.notifier)
          .update((filter) => filter.selectScope(widget.scope));
    });
  }

  bool _isSynced(ArticleListFilter filter) {
    final next = filter.selectScope(widget.scope);
    return filter.scope == next.scope &&
        filter.unreadOnly == next.unreadOnly &&
        filter.searchQuery == next.searchQuery;
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(articleListFilterProvider);
    if (!_isSynced(filter)) {
      _scheduleScopeSync();
      return const ColoredBox(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return HomeScreen(selectedArticleId: widget.selectedArticleId);
  }
}
