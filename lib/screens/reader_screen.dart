import 'package:flutter/material.dart';

import '../features/reader/reader.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.articleId,
    this.fallbackBackLocation = '/',
  });

  final int articleId;
  final String fallbackBackLocation;

  @override
  Widget build(BuildContext context) {
    return ReaderView(
      key: ValueKey('reader-$articleId'),
      articleId: articleId,
      showBack: true,
      fallbackBackLocation: fallbackBackLocation,
    );
  }
}
