class ParsedFeed {
  const ParsedFeed({
    required this.title,
    required this.siteUrl,
    required this.description,
    required this.items,
  });

  final String? title;
  final String? siteUrl;
  final String? description;
  final List<ParsedItem> items;
}

class ParsedItem {
  const ParsedItem({
    required this.remoteId,
    required this.link,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.contentHtml,
  });

  final String? remoteId;
  final String link;
  final String? title;
  final String? author;
  final DateTime? publishedAt;
  final String? contentHtml;
}

