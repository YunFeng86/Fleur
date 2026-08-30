import 'dart:convert';

import 'package:dio/dio.dart';

import '../../network/response_shape_exception.dart';

class MinifluxClient {
  MinifluxClient({
    required Dio dio,
    required String baseUrl,
    String? apiToken,
    String? username,
    String? password,
  }) : _dio = dio,
       _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _apiToken = apiToken?.trim(),
       _basicUsername = username?.trim(),
       _basicPassword = password;

  final Dio _dio;
  final String _baseUrl;
  final String? _apiToken;
  final String? _basicUsername;
  final String? _basicPassword;

  Map<String, Object?> get _authHeaders {
    final token = (_apiToken ?? '').trim();
    if (token.isNotEmpty) {
      return <String, Object?>{'X-Auth-Token': token};
    }

    final u = (_basicUsername ?? '').trim();
    final p = _basicPassword;
    if (u.isNotEmpty && p != null) {
      final raw = '$u:$p';
      final encoded = base64Encode(utf8.encode(raw));
      return <String, Object?>{'Authorization': 'Basic $encoded'};
    }

    return const <String, Object?>{};
  }

  Options get _options =>
      Options(headers: _authHeaders, responseType: ResponseType.json);

  Map<String, Object?> _readResponseMap(
    Object? data, {
    required String context,
  }) {
    if (data is Map && data.keys.every((key) => key is String)) {
      return data.cast<String, Object?>();
    }
    throw ResponseShapeException(
      backend: 'miniflux',
      endpoint: context,
      field: '<root>',
      expectedType: 'object',
      actualType: data.runtimeType.toString(),
    );
  }

  Map<String, Object?> _readEntriesResponse(
    Object? data, {
    required String context,
  }) {
    final response = _readResponseMap(data, context: context);
    final entries = response['entries'];
    if (entries is! List ||
        entries.any(
          (entry) => entry is! Map || entry.keys.any((key) => key is! String),
        )) {
      throw ResponseShapeException(
        backend: 'miniflux',
        endpoint: context,
        field: 'entries',
        expectedType: 'list<object>',
        actualType: entries.runtimeType.toString(),
      );
    }
    final total = response['total'];
    if (total != null && total is! int) {
      throw ResponseShapeException(
        backend: 'miniflux',
        endpoint: context,
        field: 'total',
        expectedType: 'integer',
        actualType: total.runtimeType.toString(),
      );
    }
    return response;
  }

  Future<Map<String, Object?>> getEntry(int entryId) async {
    final resp = await _dio.get(
      '$_baseUrl/v1/entries/$entryId',
      options: _options,
    );
    return _readResponseMap(resp.data, context: 'entry $entryId');
  }

  Future<List<Map<String, Object?>>> getCategories() async {
    final resp = await _dio.get('$_baseUrl/v1/categories', options: _options);
    return _readResponseMapList(resp.data, context: 'categories');
  }

  Future<List<Map<String, Object?>>> getFeeds() async {
    final resp = await _dio.get('$_baseUrl/v1/feeds', options: _options);
    return _readResponseMapList(resp.data, context: 'feeds');
  }

  List<Map<String, Object?>> _readResponseMapList(
    Object? data, {
    required String context,
  }) {
    if (data is! List) {
      throw ResponseShapeException(
        backend: 'miniflux',
        endpoint: context,
        field: '<root>',
        expectedType: 'list<object>',
        actualType: data.runtimeType.toString(),
      );
    }
    final result = <Map<String, Object?>>[];
    for (final item in data) {
      if (item is! Map || item.keys.any((key) => key is! String)) {
        throw ResponseShapeException(
          backend: 'miniflux',
          endpoint: context,
          field: '<item>',
          expectedType: 'object',
          actualType: item.runtimeType.toString(),
          itemIndex: result.length,
        );
      }
      result.add(item.cast<String, Object?>());
    }
    return List.unmodifiable(result);
  }

  Future<Map<String, Object?>> getEntries({
    required int limit,
    int offset = 0,
    // Miniflux expects one or more "status" query params.
    // Docs: status = read | unread | removed (can be repeated).
    // We default to the common "all visible" set (unread + read).
    List<String> statuses = const ['unread', 'read'],
    String order = 'published_at',
    String direction = 'desc',
  }) async {
    final resp = await _dio.get(
      '$_baseUrl/v1/entries',
      options: _options,
      queryParameters: <String, Object?>{
        'limit': limit,
        if (offset > 0) 'offset': offset,
        if (statuses.isNotEmpty) 'status': statuses,
        'order': order,
        'direction': direction,
      },
    );
    return _readEntriesResponse(resp.data, context: 'entries');
  }

  Future<Map<String, Object?>> getFeedEntries({
    required int feedId,
    required int limit,
    int offset = 0,
    List<String> statuses = const ['unread', 'read'],
    String order = 'published_at',
    String direction = 'desc',
  }) async {
    if (feedId <= 0) {
      throw ArgumentError('Feed id is invalid');
    }
    final resp = await _dio.get(
      '$_baseUrl/v1/feeds/$feedId/entries',
      options: _options,
      queryParameters: <String, Object?>{
        'limit': limit,
        if (offset > 0) 'offset': offset,
        if (statuses.isNotEmpty) 'status': statuses,
        'order': order,
        'direction': direction,
      },
    );
    return _readEntriesResponse(resp.data, context: 'feed $feedId entries');
  }

  Future<void> setEntriesStatus(
    List<int> entryIds, {
    required String status,
  }) async {
    if (entryIds.isEmpty) return;
    await _dio.put(
      '$_baseUrl/v1/entries',
      options: _options,
      data: <String, Object?>{'entry_ids': entryIds, 'status': status},
    );
  }

  /// Miniflux API: PUT /v1/entries/{id}/bookmark (toggle starred flag).
  Future<void> toggleBookmark(int entryId) async {
    await _dio.put('$_baseUrl/v1/entries/$entryId/bookmark', options: _options);
  }

  /// Pseudo-idempotent "set starred": fetch remote state and toggle only if needed.
  /// This avoids the non-idempotent toggle hazard during retries/outbox replay.
  Future<void> setBookmarkState(int entryId, bool targetStarred) async {
    final entry = await getEntry(entryId);
    final starred = entry['starred'];
    if (starred is! bool) {
      throw StateError('Missing "starred" field for entry $entryId');
    }
    final remoteStarred = starred;
    if (remoteStarred == targetStarred) return;
    await toggleBookmark(entryId);
  }

  Future<void> markFeedAllAsRead(int feedId) async {
    await _dio.put(
      '$_baseUrl/v1/feeds/$feedId/mark-all-as-read',
      options: _options,
    );
  }

  Future<void> markCategoryAllAsRead(int categoryId) async {
    await _dio.put(
      '$_baseUrl/v1/categories/$categoryId/mark-all-as-read',
      options: _options,
    );
  }

  Future<String> fetchEntryContent(
    int entryId, {
    bool updateContent = false,
  }) async {
    final resp = await _dio.get(
      '$_baseUrl/v1/entries/$entryId/fetch-content',
      options: _options,
      queryParameters: <String, Object?>{'update_content': updateContent},
    );
    final data = resp.data;
    if (data is Map) {
      final content = data['content'];
      if (content is String) return content;
    }
    return '';
  }

  Future<Map<String, Object?>> createCategory(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category title is empty');
    }

    final resp = await _dio.post(
      '$_baseUrl/v1/categories',
      options: _options,
      data: <String, Object?>{'title': trimmed},
    );
    return _readResponseMap(resp.data, context: 'create category');
  }

  Future<Map<String, Object?>> createFeed({
    required String feedUrl,
    required int categoryId,
  }) async {
    final normalized = feedUrl.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Feed url is empty');
    }
    if (categoryId <= 0) {
      throw ArgumentError('Category id is invalid');
    }

    final resp = await _dio.post(
      '$_baseUrl/v1/feeds',
      options: _options,
      data: <String, Object?>{
        'feed_url': normalized,
        'category_id': categoryId,
      },
    );
    return _readResponseMap(resp.data, context: 'create feed');
  }

  Future<Map<String, Object?>> updateFeed({
    required int feedId,
    int? categoryId,
    String? title,
  }) async {
    if (feedId <= 0) {
      throw ArgumentError('Feed id is invalid');
    }

    final data = <String, Object?>{};
    if (categoryId != null) {
      if (categoryId <= 0) {
        throw ArgumentError('Category id is invalid');
      }
      data['category_id'] = categoryId;
    }
    if (title != null) {
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) {
        throw ArgumentError('Feed title is empty');
      }
      data['title'] = trimmedTitle;
    }
    if (data.isEmpty) {
      throw ArgumentError('No feed fields to update');
    }

    final resp = await _dio.put(
      '$_baseUrl/v1/feeds/$feedId',
      options: _options,
      data: data,
    );
    return _readResponseMap(resp.data, context: 'update feed $feedId');
  }

  Future<void> deleteFeed(int feedId) async {
    if (feedId <= 0) {
      throw ArgumentError('Feed id is invalid');
    }
    await _dio.delete('$_baseUrl/v1/feeds/$feedId', options: _options);
  }

  Future<void> refreshFeed(int feedId) async {
    if (feedId <= 0) {
      throw ArgumentError('Feed id is invalid');
    }
    await _dio.put('$_baseUrl/v1/feeds/$feedId/refresh', options: _options);
  }

  Future<void> refreshAllFeeds() async {
    await _dio.put('$_baseUrl/v1/feeds/refresh', options: _options);
  }

  Future<Map<String, Object?>> updateCategory({
    required int categoryId,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (categoryId <= 0) {
      throw ArgumentError('Category id is invalid');
    }
    if (trimmed.isEmpty) {
      throw ArgumentError('Category title is empty');
    }

    final resp = await _dio.put(
      '$_baseUrl/v1/categories/$categoryId',
      options: _options,
      data: <String, Object?>{'title': trimmed},
    );
    return _readResponseMap(resp.data, context: 'update category $categoryId');
  }

  Future<void> deleteCategory(int categoryId) async {
    if (categoryId <= 0) {
      throw ArgumentError('Category id is invalid');
    }
    await _dio.delete('$_baseUrl/v1/categories/$categoryId', options: _options);
  }
}
