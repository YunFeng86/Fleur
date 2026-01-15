import 'package:flutter/material.dart';

import '../widgets/reader_view.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.articleId});

  final int articleId;

  @override
  Widget build(BuildContext context) {
    return ReaderView(articleId: articleId);
  }
}
