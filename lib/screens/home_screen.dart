import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/article_list.dart';
import '../widgets/reader_view.dart';
import '../widgets/sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    if (!isWide) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flutter Reader')),
        drawer: Drawer(
          child: Sidebar(
            onSelectFeed: (_) {
              Navigator.of(context).maybePop(); // close drawer
            },
          ),
        ),
        body: ArticleList(selectedArticleId: selectedArticleId),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Sidebar(
              onSelectFeed: (_) {
                if (selectedArticleId != null) context.go('/');
              },
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 420,
            child: Column(
              children: [
                const SizedBox(height: 56, child: Center(child: Text('Articles'))),
                const Divider(height: 1),
                Expanded(child: ArticleList(selectedArticleId: selectedArticleId)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selectedArticleId == null
                ? const Center(child: Text('Select an article'))
                : ReaderView(articleId: selectedArticleId!, embedded: true),
          ),
        ],
      ),
    );
  }
}
