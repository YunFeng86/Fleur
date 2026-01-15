import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.onSelectFeed});

  final void Function(int? feedId) onSelectFeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeds = ref.watch(feedsProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subscriptions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Add',
                  onPressed: () => _showAddFeedDialog(context, ref),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Refresh selected',
                  onPressed: selectedFeedId == null
                      ? null
                      : () async {
                          await ref
                              .read(syncServiceProvider)
                              .refreshFeed(selectedFeedId);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Refreshed')),
                          );
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: feeds.when(
              data: (items) {
                return ListView(
                  children: [
                    ListTile(
                      selected: selectedFeedId == null,
                      leading: const Icon(Icons.all_inbox),
                      title: const Text('All'),
                      onTap: () => _select(ref, null),
                    ),
                    for (final f in items)
                      ListTile(
                        selected: selectedFeedId == f.id,
                        leading: const Icon(Icons.rss_feed),
                        title: Text(f.title?.trim().isNotEmpty == true
                            ? f.title!
                            : f.url),
                        subtitle: f.title?.trim().isNotEmpty == true
                            ? Text(f.url, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () => _select(ref, f.id),
                        onLongPress: () => _confirmDelete(context, ref, f.id),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, int? id) {
    ref.read(selectedFeedIdProvider.notifier).state = id;
    onSelectFeed(id);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int feedId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete subscription?'),
          content: const Text('This will delete its cached articles too.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await ref.read(feedRepositoryProvider).delete(feedId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted')),
    );
  }

  Future<void> _showAddFeedDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add subscription'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'RSS/Atom URL',
              hintText: 'https://example.com/feed.xml',
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (url == null || url.trim().isEmpty) return;

    final id = await ref.read(feedRepositoryProvider).upsertUrl(url);
    await ref.read(syncServiceProvider).refreshFeed(id);
    ref.read(selectedFeedIdProvider.notifier).state = id;
    onSelectFeed(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added & synced')),
    );
  }
}

