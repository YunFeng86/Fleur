import 'dart:convert';

import 'package:dio/dio.dart';

class GoogleReaderAuthException implements Exception {
  const GoogleReaderAuthException(this.message);

  final String message;

  @override
  String toString() => 'GoogleReaderAuthException($message)';
}

class GoogleReaderItemIdsPage {
  const GoogleReaderItemIdsPage({
    required this.itemIds,
    required this.continuation,
  });

  final List<String> itemIds;
  final String? continuation;
}

class GoogleReaderClient {
  GoogleReaderClient({
    required Dio dio,
    required String baseUrl,
    String? authToken,
    String? username,
    String? password,
  }) : _dio = dio,
       _base = _GoogleReaderBaseUris.fromRaw(baseUrl),
       _authToken = authToken?.trim(),
       _username = username?.trim(),
       _password = password;

  final Dio _dio;
  final _GoogleReaderBaseUris _base;
  String? _authToken;
  String? _writeToken;
  final String? _username;
  final String? _password;

  Options get _jsonOptions => Options(
    headers: <String, Object?>{'Authorization': 'GoogleLogin auth=$_auth'},
    responseType: ResponseType.json,
  );

  Options get _formOptions => Options(
    headers: <String, Object?>{'Authorization': 'GoogleLogin auth=$_auth'},
    contentType: Headers.formUrlEncodedContentType,
    responseType: ResponseType.json,
  );

  String get _auth {
    final token = _authToken?.trim();
    if (token == null || token.isEmpty) {
      throw const GoogleReaderAuthException('Missing auth token');
    }
    return token;
  }

  Future<void> ensureAuthenticated() async {
    final token = _authToken?.trim();
    if (token != null && token.isNotEmpty) return;
    final username = _username?.trim();
    final password = _password;
    if (username == null || username.isEmpty || password == null) {
      throw const GoogleReaderAuthException('Missing credentials');
    }
    _authToken = await clientLogin(username: username, password: password);
  }

  Future<String> clientLogin({
    required String username,
    required String password,
  }) async {
    final resp = await _dio.postUri(
      _base.authUri(const ['accounts', 'ClientLogin']),
      data: <String, Object?>{
        'Email': username,
        'Passwd': password,
        'service': 'reader',
        'accountType': 'HOSTED_OR_GOOGLE',
        'output': 'json',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
      ),
    );
    final token = _parseClientLoginAuth(resp.data);
    if (token == null || token.isEmpty) {
      throw const GoogleReaderAuthException(
        'ClientLogin response missing Auth',
      );
    }
    _authToken = token;
    return token;
  }

  Future<String> token() async {
    await ensureAuthenticated();
    final cached = _writeToken?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    final resp = await _dio.getUri(
      _base.apiUri(const ['token']),
      options: Options(
        headers: <String, Object?>{'Authorization': 'GoogleLogin auth=$_auth'},
        responseType: ResponseType.plain,
      ),
    );
    final raw = resp.data;
    final token = raw is String ? raw.trim() : raw?.toString().trim();
    if (token == null || token.isEmpty) {
      throw const GoogleReaderAuthException('Token response is empty');
    }
    _writeToken = token;
    return token;
  }

  Future<List<Map<String, Object?>>> subscriptionList() async {
    await ensureAuthenticated();
    final resp = await _dio.getUri(
      _base.apiUri(
        const ['subscription', 'list'],
        queryParameters: const <String, Object?>{'output': 'json'},
      ),
      options: _jsonOptions,
    );
    final data = resp.data;
    if (data is! Map) return const [];
    final subscriptions = data['subscriptions'];
    if (subscriptions is! List) return const [];
    return subscriptions
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
  }

  Future<GoogleReaderItemIdsPage> streamItemIds({
    required String streamId,
    int count = 100,
    String? continuation,
    String? excludeState,
    int? olderThanSeconds,
  }) async {
    await ensureAuthenticated();
    final resp = await _dio.getUri(
      _base.apiUri(
        const ['stream', 'items', 'ids'],
        queryParameters: {
          'output': 'json',
          's': streamId,
          'n': count,
          if (continuation != null && continuation.trim().isNotEmpty)
            'c': continuation.trim(),
          if (excludeState != null && excludeState.trim().isNotEmpty)
            'xt': excludeState.trim(),
          'ot': ?olderThanSeconds,
        },
      ),
      options: _jsonOptions,
    );
    final data = resp.data;
    if (data is! Map) {
      return const GoogleReaderItemIdsPage(itemIds: [], continuation: null);
    }
    final refs = data['itemRefs'];
    final ids = refs is List
        ? refs
              .whereType<Map>()
              .map((item) => item['id']?.toString().trim())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final next = data['continuation']?.toString().trim();
    return GoogleReaderItemIdsPage(
      itemIds: ids,
      continuation: next == null || next.isEmpty ? null : next,
    );
  }

  Future<List<Map<String, Object?>>> streamItemsContents(
    Iterable<String> itemIds,
  ) async {
    await ensureAuthenticated();
    final ids = itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    if (ids.isEmpty) return const [];
    final resp = await _dio.postUri(
      _base.apiUri(const ['stream', 'items', 'contents']),
      data: <String, Object?>{
        'output': 'json',
        'i': ids.toList(growable: false),
        'T': await token(),
      },
      options: _formOptions,
    );
    final data = resp.data;
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
  }

  Future<void> editTag({
    required String itemId,
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
  }) async {
    await ensureAuthenticated();
    await _dio.postUri(
      _base.apiUri(const ['edit-tag']),
      data: <String, Object?>{
        'i': itemId,
        'a': add
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        'r': remove
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        'T': await token(),
      },
      options: _formOptions,
    );
  }

  Future<void> markAllAsRead({
    required String streamId,
    DateTime? before,
  }) async {
    await ensureAuthenticated();
    await _dio.postUri(
      _base.apiUri(const ['mark-all-as-read']),
      data: <String, Object?>{
        's': streamId,
        if (before != null)
          'ts': before.toUtc().microsecondsSinceEpoch.toString(),
        'T': await token(),
      },
      options: _formOptions,
    );
  }

  static String? _parseClientLoginAuth(Object? data) {
    if (data is Map) {
      return _authFromMap(data);
    }
    final text = data?.toString().trim();
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final token = _authFromMap(decoded);
        if (token != null && token.isNotEmpty) return token;
      }
    } on FormatException {
      // ClientLogin-compatible services may still return the legacy key=value
      // body even when output=json is present.
    }
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      if (key != 'Auth') continue;
      final value = line.substring(idx + 1).trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _authFromMap(Map<Object?, Object?> data) {
    final auth = data['Auth'] ?? data['auth'];
    final token = auth?.toString().trim();
    return token == null || token.isEmpty ? null : token;
  }
}

class _GoogleReaderBaseUris {
  const _GoogleReaderBaseUris({required this.authBase, required this.apiBase});

  final Uri authBase;
  final Uri apiBase;

  factory _GoogleReaderBaseUris.fromRaw(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw ArgumentError('Google Reader baseUrl is empty');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw ArgumentError('Google Reader baseUrl is invalid: $raw');
    }
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('Google Reader baseUrl must be http/https: $raw');
    }
    final clean = uri.replace(query: '', fragment: '');
    const apiSuffix = '/reader/api/0';
    if (clean.path.endsWith(apiSuffix)) {
      final authPath = clean.path.substring(
        0,
        clean.path.length - apiSuffix.length,
      );
      return _GoogleReaderBaseUris(
        authBase: clean.replace(path: authPath.isEmpty ? '/' : authPath),
        apiBase: clean,
      );
    }
    final apiPath = _appendPath(clean.path, const ['reader', 'api', '0']);
    return _GoogleReaderBaseUris(
      authBase: clean,
      apiBase: clean.replace(path: apiPath),
    );
  }

  Uri authUri(List<String> segments) {
    return authBase.replace(path: _appendPath(authBase.path, segments));
  }

  Uri apiUri(
    List<String> segments, {
    Map<String, Object?> queryParameters = const {},
  }) {
    final uri = apiBase.replace(path: _appendPath(apiBase.path, segments));
    if (queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  static String _appendPath(String basePath, List<String> segments) {
    final cleanBase = basePath.replaceAll(RegExp(r'/+$'), '');
    final encoded = segments.map(Uri.encodeComponent).join('/');
    if (cleanBase.isEmpty) return '/$encoded';
    return '$cleanBase/$encoded';
  }
}
