import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/cache/ai_content_cache_store.dart';

void main() {
  test('AiContentCacheEntry.fromJson rejects non-finite article ids', () {
    final entry = AiContentCacheEntry.fromJson(<String, Object?>{
      'key': <String, Object?>{
        'accountId': 'account-1',
        'articleId': double.infinity,
        'targetLanguageTag': 'en',
        'kind': 'summary',
        'aiServiceId': 'service-1',
      },
      'contentHash': 'content-hash',
      'data': 'cached text',
      'updatedAt': '2026-03-01T00:00:00.000Z',
    });

    expect(entry, isNull);
  });
}
