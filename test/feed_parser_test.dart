import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reader/services/rss/feed_parser.dart';

void main() {
  test('parses RSS', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example</title>
    <link>https://example.com</link>
    <description>Desc</description>
    <item>
      <title>Hello</title>
      <link>https://example.com/1</link>
      <guid>1</guid>
      <pubDate>Tue, 06 Aug 2024 10:00:00 +0000</pubDate>
      <description><![CDATA[<p>Hi</p>]]></description>
    </item>
  </channel>
</rss>
''';
    final parsed = FeedParser().parse(xml);
    expect(parsed.title, 'Example');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.first.link, 'https://example.com/1');
    expect(parsed.items.first.contentHtml, contains('<p>Hi</p>'));
  });

  test('parses Atom', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Example</title>
  <link href="https://example.com"/>
  <updated>2024-08-06T10:00:00Z</updated>
  <entry>
    <id>tag:example.com,2024:1</id>
    <title>Hello</title>
    <link rel="alternate" href="https://example.com/1"/>
    <updated>2024-08-06T10:00:00Z</updated>
    <summary><![CDATA[<p>Hi</p>]]></summary>
  </entry>
</feed>
''';
    final parsed = FeedParser().parse(xml);
    expect(parsed.title, 'Example');
    expect(parsed.items, hasLength(1));
    expect(parsed.items.first.link, 'https://example.com/1');
    expect(parsed.items.first.contentHtml, contains('<p>Hi</p>'));
  });
}

