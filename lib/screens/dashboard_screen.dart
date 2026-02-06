import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/article.dart';
import '../models/feed.dart';
import '../providers/app_settings_providers.dart';
import '../providers/query_providers.dart';
import '../ui/settings/subscriptions/subscription_actions.dart';
import '../utils/platform.dart';
import '../utils/timeago_locale.dart';

final RegExp _previewImageRegex = RegExp(
  r'<img[^>]+src="([^">]+)"',
  caseSensitive: false,
);

const List<String> _dashboardModuleIds = ['feeds', 'saved'];

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editing = false;

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  Future<void> _showManageModules({
    required List<String> order,
    required List<String> hidden,
    required AppLocalizations l10n,
  }) async {
    final hiddenSet = hidden.toSet();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    l10n.dashboard,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final id in _dashboardModuleIds)
                    SwitchListTile(
                      title: Text(_moduleTitle(l10n, id)),
                      value: !hiddenSet.contains(id),
                      onChanged: (value) async {
                        setSheetState(() {
                          if (value) {
                            hiddenSet.remove(id);
                          } else {
                            hiddenSet.add(id);
                          }
                        });
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setDashboardLayout(
                              moduleOrder: order,
                              hiddenModules: hiddenSet.toList(),
                            );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // On desktop we already have a top title bar (DesktopTitleBar) from App
    // chrome, so don't add a second (compact) app bar inside the page.
    final useCompactTopBar = !isDesktop;

    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final order = _normalizeDashboardOrder(settings?.dashboardModuleOrder);
    final hidden = _normalizeDashboardHidden(settings?.dashboardHiddenModules);
    final visible = order.where((id) => !hidden.contains(id)).toList();

    final feedsAsync = ref.watch(feedsProvider);
    final feeds = feedsAsync.valueOrNull ?? const <Feed>[];
    final feedMap = {for (final feed in feeds) feed.id: feed};

    final unreadPreview = ref.watch(dashboardUnreadPreviewProvider);
    final starredPreview = ref.watch(dashboardStarredPreviewProvider);
    final readLaterPreview = ref.watch(dashboardReadLaterPreviewProvider);

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 900;
        final gridExtent = wide ? 440.0 : 420.0;
        final centerTitle = switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.macOS => true,
          _ => false,
        };

        Widget buildHeaderActions() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _editing ? l10n.done : l10n.edit,
                onPressed: _toggleEdit,
                icon: Icon(_editing ? Icons.check : Icons.edit),
              ),
              IconButton(
                tooltip: l10n.add,
                onPressed: () => _showManageModules(
                  order: order,
                  hidden: hidden,
                  l10n: l10n,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          );
        }

        Widget grid;
        if (visible.isEmpty) {
          grid = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.notFound,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _showManageModules(
                    order: order,
                    hidden: hidden,
                    l10n: l10n,
                  ),
                  child: Text(l10n.add),
                ),
              ],
            ),
          );
        } else if (_editing) {
          grid = ReorderableGridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 2 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: gridExtent,
            ),
            itemCount: visible.length,
            onReorder: (oldIndex, newIndex) async {
              final nextOrder = _reorderVisibleInOrder(
                order,
                hidden.toSet(),
                oldIndex,
                newIndex,
              );
              await ref
                  .read(appSettingsProvider.notifier)
                  .setDashboardLayout(moduleOrder: nextOrder);
            },
            itemBuilder: (context, index) {
              final id = visible[index];
              return _ModuleItem(
                key: ValueKey(id),
                editing: _editing,
                onHide: () async {
                  final nextHidden = {...hidden, id}.toList();
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setDashboardLayout(
                        moduleOrder: order,
                        hiddenModules: nextHidden,
                      );
                },
                child: _buildModule(
                  id,
                  context: context,
                  ref: ref,
                  l10n: l10n,
                  theme: theme,
                  feedMap: feedMap,
                  unreadPreview: unreadPreview,
                  starredPreview: starredPreview,
                  readLaterPreview: readLaterPreview,
                  editing: _editing,
                ),
              );
            },
          );
        } else {
          grid = GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 2 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: gridExtent,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final id = visible[index];
              return _ModuleItem(
                key: ValueKey(id),
                editing: _editing,
                onHide: () async {
                  final nextHidden = {...hidden, id}.toList();
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setDashboardLayout(
                        moduleOrder: order,
                        hiddenModules: nextHidden,
                      );
                },
                child: _buildModule(
                  id,
                  context: context,
                  ref: ref,
                  l10n: l10n,
                  theme: theme,
                  feedMap: feedMap,
                  unreadPreview: unreadPreview,
                  starredPreview: starredPreview,
                  readLaterPreview: readLaterPreview,
                  editing: _editing,
                ),
              );
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!useCompactTopBar) ...[
                // Desktop already shows the section title in DesktopTitleBar.
                // Keep only actions here to avoid a double title bar effect.
                if (isDesktop)
                  Align(
                    alignment: Alignment.centerRight,
                    child: buildHeaderActions(),
                  )
                else if (centerTitle)
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0,
                            child: buildHeaderActions(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            l10n.dashboard,
                            style: theme.textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      buildHeaderActions(),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dashboard,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      buildHeaderActions(),
                    ],
                  ),
                const SizedBox(height: 12),
              ],
              grid,
            ],
          ),
        );
      },
    );

    if (!useCompactTopBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          IconButton(
            tooltip: _editing ? l10n.done : l10n.edit,
            onPressed: _toggleEdit,
            icon: Icon(_editing ? Icons.check : Icons.edit),
          ),
          IconButton(
            tooltip: l10n.add,
            onPressed: () =>
                _showManageModules(order: order, hidden: hidden, l10n: l10n),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }
}

Widget _buildModule(
  String id, {
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
  required ThemeData theme,
  required Map<int, Feed> feedMap,
  required AsyncValue<List<Article>> unreadPreview,
  required AsyncValue<List<Article>> starredPreview,
  required AsyncValue<List<Article>> readLaterPreview,
  required bool editing,
}) {
  switch (id) {
    case 'feeds':
      return _SectionCard(
        title: l10n.feeds,
        trailing: TextButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.showAll),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              ignoring: editing,
              child: Opacity(
                opacity: editing ? 0.6 : 1,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await SubscriptionActions.showAddFeedDialog(
                          context,
                          ref,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addSubscription),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await SubscriptionActions.refreshAll(context, ref);
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.refreshAll),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PreviewList(
              title: l10n.unread,
              items: unreadPreview,
              feedMap: feedMap,
              emptyText: l10n.noUnreadArticles,
              maxItems: 3,
              onArticleTap: (article) => context.go('/article/${article.id}'),
            ),
          ],
        ),
      );
    case 'saved':
      return _SectionCard(
        title: l10n.saved,
        trailing: TextButton(
          onPressed: () => context.go('/saved'),
          child: Text(l10n.showAll),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewList(
              title: l10n.starred,
              items: starredPreview,
              feedMap: feedMap,
              emptyText: l10n.noArticles,
              maxItems: 2,
              onArticleTap: (article) => context.go('/article/${article.id}'),
            ),
            const SizedBox(height: 16),
            _PreviewList(
              title: l10n.readLater,
              items: readLaterPreview,
              feedMap: feedMap,
              emptyText: l10n.noArticles,
              maxItems: 2,
              onArticleTap: (article) => context.go('/article/${article.id}'),
            ),
          ],
        ),
      );
    default:
      return _SectionCard(
        title: l10n.dashboard,
        child: Text(
          l10n.notFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
  }
}

String _moduleTitle(AppLocalizations l10n, String id) {
  return switch (id) {
    'feeds' => l10n.feeds,
    'saved' => l10n.saved,
    _ => l10n.dashboard,
  };
}

List<String> _normalizeDashboardOrder(List<String>? raw) {
  final seen = <String>{};
  final out = <String>[];
  if (raw != null) {
    for (final id in raw) {
      if (_dashboardModuleIds.contains(id) && seen.add(id)) {
        out.add(id);
      }
    }
  }
  for (final id in _dashboardModuleIds) {
    if (seen.add(id)) out.add(id);
  }
  return out;
}

List<String> _normalizeDashboardHidden(List<String>? raw) {
  if (raw == null) return const [];
  return raw.where(_dashboardModuleIds.contains).toSet().toList();
}

List<String> _reorderVisibleInOrder(
  List<String> order,
  Set<String> hidden,
  int oldIndex,
  int newIndex,
) {
  final visible = order.where((id) => !hidden.contains(id)).toList();
  if (oldIndex < 0 || oldIndex >= visible.length) return order;
  if (newIndex < 0) return order;
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  if (target < 0) target = 0;
  if (target >= visible.length) target = visible.length - 1;
  final item = visible.removeAt(oldIndex);
  visible.insert(target, item);
  var cursor = 0;
  return order
      .map((id) => hidden.contains(id) ? id : visible[cursor++])
      .toList();
}

class _ModuleItem extends StatelessWidget {
  const _ModuleItem({
    super.key,
    required this.child,
    required this.editing,
    required this.onHide,
  });

  final Widget child;
  final bool editing;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(ignoring: editing, child: child),
        ),
        if (editing)
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                tooltip: AppLocalizations.of(context)!.delete,
                icon: const Icon(Icons.close),
                onPressed: onHide,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({
    required this.title,
    required this.items,
    required this.feedMap,
    required this.emptyText,
    required this.maxItems,
    required this.onArticleTap,
  });

  final String title;
  final AsyncValue<List<Article>> items;
  final Map<int, Feed> feedMap;
  final String emptyText;
  final int maxItems;
  final void Function(Article article) onArticleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        items.when(
          data: (list) {
            if (list.isEmpty) {
              return Text(
                emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            final visible = list.take(maxItems).toList();
            return Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _ArticlePreviewTile(
                    article: visible[i],
                    feed: feedMap[visible[i].feedId],
                    onTap: () => onArticleTap(visible[i]),
                  ),
                  if (i != visible.length - 1)
                    Divider(
                      height: 12,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stackTrace) => Text(
            AppLocalizations.of(context)!.errorMessage(error.toString()),
          ),
        ),
      ],
    );
  }
}

class _ArticlePreviewTile extends StatelessWidget {
  const _ArticlePreviewTile({
    required this.article,
    required this.feed,
    required this.onTap,
  });

  final Article article;
  final Feed? feed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _articleTitle(article);
    final feedTitle = _feedTitle(feed) ?? article.link;
    final timeStr = timeago.format(
      article.publishedAt.toLocal(),
      locale: timeagoLocale(context),
    );
    final imageUrl = _previewImageUrl(article);
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 64,
                    height: 48,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stackTrace) => Icon(
                        Icons.broken_image,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$feedTitle · $timeStr',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _articleTitle(Article article) {
  final title = article.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return article.link;
}

String? _feedTitle(Feed? feed) {
  if (feed == null) return null;
  final userTitle = feed.userTitle?.trim();
  if (userTitle != null && userTitle.isNotEmpty) return userTitle;
  final title = feed.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return feed.url;
}

String? _previewImageUrl(Article article) {
  final html = article.extractedContentHtml?.trim().isNotEmpty == true
      ? article.extractedContentHtml
      : article.contentHtml;
  if (html == null || html.trim().isEmpty) return null;
  final match = _previewImageRegex.firstMatch(html);
  return match?.group(1);
}
