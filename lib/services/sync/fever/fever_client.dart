import 'package:dio/dio.dart';

class FeverAuthException implements Exception {
  FeverAuthException();

  @override
  String toString() => 'FeverAuthException(auth=0)';
}

class FeverClient {
  FeverClient({
    required Dio dio,
    required String baseUrl,
    required String apiKey,
  }) : _dio = dio,
       _baseUri = _normalizeBaseUri(baseUrl),
       _apiKey = apiKey.trim();

  final Dio _dio;
  final Uri _baseUri;
  final String _apiKey;

  static Uri _normalizeBaseUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Fever baseUrl is empty');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw ArgumentError('Fever baseUrl is invalid: $raw');
    }
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('Fever baseUrl must be http/https: $raw');
    }
    // Fever uses `?api` query; strip any existing query/fragment to build our own.
    return uri.replace(query: '', fragment: '');
  }

  Uri _buildUri({
    List<String> flags = const [],
    Map<String, String> params = const {},
  }) {
    final parts = <String>['api', ...flags];
    for (final entry in params.entries) {
      final k = Uri.encodeQueryComponent(entry.key);
      final v = Uri.encodeQueryComponent(entry.value);
      parts.add('$k=$v');
    }
    return _baseUri.replace(query: parts.join('&'));
  }

  Options get _options => Options(
    contentType: Headers.formUrlEncodedContentType,
    responseType: ResponseType.json,
  );

  static bool _truthy(Object? v) {
    if (v is bool) return v;
    if (v is num) return v.isFinite && v.toInt() == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true';
    }
    return false;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.isFinite ? v.toInt() : null;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  Future<Map<String, Object?>> _post(Uri uri) async {
    final resp = await _dio.postUri(
      uri,
      data: <String, Object?>{'api_key': _apiKey},
      options: _options,
    );
    final data = resp.data;
    if (data is! Map || data.keys.any((key) => key is! String)) {
      throw StateError('Unexpected Fever response');
    }
    final map = data.cast<String, Object?>();
    if (_truthy(map['auth'])) return map;
    throw FeverAuthException();
  }

  Future<void> validate() async {
    await _post(_buildUri());
  }

  Future<List<Map<String, Object?>>> getFeeds() async {
    final data = await _post(_buildUri(flags: const ['feeds']));
    return _asListOfMaps(data['feeds'], context: 'feeds');
  }

  Future<List<Map<String, Object?>>> getGroups() async {
    final data = await _post(_buildUri(flags: const ['groups']));
    return _asListOfMaps(data['groups'], context: 'groups');
  }

  /// Returns group -> feedIds mapping objects: `{group_id, feed_ids}`.
  Future<List<Map<String, Object?>>> getFeedsGroups() async {
    final data = await _post(_buildUri(flags: const ['feeds', 'groups']));
    return _asListOfMaps(data['feeds_groups'], context: 'feeds_groups');
  }

  Future<List<int>> getUnreadItemIds() async {
    final data = await _post(_buildUri(flags: const ['unread_item_ids']));
    return _parseIdList(data['unread_item_ids']);
  }

  Future<List<int>> getSavedItemIds() async {
    final data = await _post(_buildUri(flags: const ['saved_item_ids']));
    return _parseIdList(data['saved_item_ids']);
  }

  /// Fetches up to 50 items by IDs.
  Future<List<Map<String, Object?>>> getItemsWithIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final limited = ids.length > 50 ? ids.sublist(0, 50) : ids;
    final data = await _post(
      _buildUri(
        flags: const ['items'],
        params: {'with_ids': limited.join(',')},
      ),
    );
    return _asListOfMaps(data['items'], context: 'items');
  }

  Future<void> markItemRead(int itemId, {required bool read}) async {
    await _post(
      _buildUri(
        params: {
          'mark': 'item',
          'as': read ? 'read' : 'unread',
          'id': itemId.toString(),
        },
      ),
    );
  }

  Future<void> markItemSaved(int itemId, {required bool saved}) async {
    await _post(
      _buildUri(
        params: {
          'mark': 'item',
          'as': saved ? 'saved' : 'unsaved',
          'id': itemId.toString(),
        },
      ),
    );
  }

  Future<void> markFeedRead(int feedId, {required int beforeSeconds}) async {
    await _post(
      _buildUri(
        params: {
          'mark': 'feed',
          'as': 'read',
          'id': feedId.toString(),
          'before': beforeSeconds.toString(),
        },
      ),
    );
  }

  Future<void> markGroupRead(int groupId, {required int beforeSeconds}) async {
    await _post(
      _buildUri(
        params: {
          'mark': 'group',
          'as': 'read',
          'id': groupId.toString(),
          'before': beforeSeconds.toString(),
        },
      ),
    );
  }

  static List<Map<String, Object?>> _asListOfMaps(
    Object? value, {
    required String context,
  }) {
    if (value is! List) {
      throw StateError('Unexpected Fever response for $context');
    }
    final result = <Map<String, Object?>>[];
    for (final item in value) {
      if (item is! Map || item.keys.any((key) => key is! String)) {
        throw StateError('Unexpected Fever response for $context');
      }
      result.add(item.cast<String, Object?>());
    }
    return List.unmodifiable(result);
  }

  static List<int> _parseIdList(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      final result = <int>[];
      for (final part in trimmed.split(',')) {
        final id = int.tryParse(part.trim());
        if (id == null) {
          throw StateError('Unexpected Fever response for item ids');
        }
        result.add(id);
      }
      return List.unmodifiable(result);
    }
    if (value is List) {
      final result = <int>[];
      for (final item in value) {
        final id = _asInt(item);
        if (id == null || (item is num && item != id)) {
          throw StateError('Unexpected Fever response for item ids');
        }
        result.add(id);
      }
      return List.unmodifiable(result);
    }
    throw StateError('Unexpected Fever response for item ids');
  }
}
