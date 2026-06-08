import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import '../logging/log_context.dart';
import '../settings/translation_ai_secret_store.dart';
import '../settings/translation_ai_settings.dart';
import '../../utils/language_utils.dart';

class TranslationService {
  TranslationService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  String? _bingToken;
  DateTime? _bingTokenExpiresAt;

  Future<String> translateText({
    required TranslationProviderSelection provider,
    required TranslationAiSettings settings,
    required TranslationAiSecretStore secrets,
    required String text,
    required String targetLanguageTag,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final tag = canonicalLanguageIdentityTag(targetLanguageTag);
    if (tag == unknownLanguageTag) {
      throw ArgumentError('targetLanguageTag is empty');
    }

    try {
      return switch (provider.kind) {
        TranslationProviderKind.googleWeb => await _translateGoogleWeb(
          trimmed,
          targetLanguageTag: tag,
        ),
        TranslationProviderKind.bingWeb => await _translateBingWeb(
          trimmed,
          targetLanguageTag: tag,
        ),
        TranslationProviderKind.baiduApi => await _translateBaiduApi(
          secrets,
          trimmed,
          targetLanguageTag: tag,
        ),
        TranslationProviderKind.deepLApi => await _translateDeepLApi(
          secrets,
          settings,
          trimmed,
          targetLanguageTag: tag,
        ),
        TranslationProviderKind.deepLX => await _translateDeepLX(
          settings,
          trimmed,
          targetLanguageTag: tag,
        ),
        TranslationProviderKind.aiService => throw UnsupportedError(
          'AI translation is handled by AiService',
        ),
      };
    } catch (e, s) {
      AppLogger.e(
        'Translate failed',
        tag: 'translate',
        error: e,
        stackTrace: s,
        context: _translationFailureContext(
          provider: provider,
          settings: settings,
          error: e,
          targetLanguageTag: tag,
        ),
      );
      rethrow;
    }
  }

  Map<String, Object?> _translationFailureContext({
    required TranslationProviderSelection provider,
    required TranslationAiSettings settings,
    required Object error,
    required String targetLanguageTag,
  }) {
    final extra = <String, Object?>{
      'operation': 'translateText',
      'provider': provider.kind.name,
      'targetLanguageTag': targetLanguageTag,
    };
    if (error is DioException) {
      return logContextForDioException(error, extra: extra);
    }
    final uri = switch (provider.kind) {
      TranslationProviderKind.googleWeb => Uri.https(
        'translate.googleapis.com',
        '/translate_a/single',
      ),
      TranslationProviderKind.bingWeb => Uri.https(
        'api-edge.cognitive.microsofttranslator.com',
        '/translate',
      ),
      TranslationProviderKind.baiduApi => Uri.https(
        'fanyi-api.baidu.com',
        '/api/trans/vip/translate',
      ),
      TranslationProviderKind.deepLApi =>
        settings.deepL.endpoint == DeepLEndpoint.free
            ? Uri.https('api-free.deepl.com', '/v2/translate')
            : Uri.https('api.deepl.com', '/v2/translate'),
      TranslationProviderKind.deepLX => () {
        final baseUrl = settings.deepLX.baseUrl.trim();
        if (baseUrl.isEmpty) return null;
        return Uri.tryParse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
      }(),
      TranslationProviderKind.aiService => null,
    };
    if (uri == null) return extra;
    return logContextForUri(uri, extra: extra);
  }

  String _googleLangCode(String tag) {
    final t = canonicalLanguageIdentityTag(tag);
    return switch (t) {
      'zh-Hans' => 'zh-CN',
      'zh-Hant' => 'zh-TW',
      _ => t.split('-').first,
    };
  }

  String _bingLangCode(String tag) {
    final t = canonicalLanguageIdentityTag(tag);
    return switch (t) {
      'zh-Hans' => 'zh-Hans',
      'zh-Hant' => 'zh-Hant',
      _ => t.split('-').first,
    };
  }

  String _deeplLangCode(String tag) {
    final t = canonicalLanguageIdentityTag(tag);
    return switch (t) {
      'zh-Hans' => 'ZH-HANS',
      'zh-Hant' => 'ZH-HANT',
      'pt-BR' => 'PT-BR',
      _ => t.split('-').first.toUpperCase(),
    };
  }

  String _baiduLangCode(String tag) {
    final t = canonicalLanguageIdentityTag(tag);
    return switch (t) {
      'zh-Hans' => 'zh',
      'zh-Hant' => 'cht',
      _ => t.split('-').first.toLowerCase(),
    };
  }

  Future<String> _translateGoogleWeb(
    String text, {
    required String targetLanguageTag,
  }) async {
    final tl = _googleLangCode(targetLanguageTag);
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': 'auto',
      'tl': tl,
      'dt': 't',
      'q': text,
    });
    final res = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    final raw = res.data ?? '';
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) {
      throw StateError('Unexpected Google translate response');
    }
    final segments = decoded.first;
    if (segments is! List) {
      throw StateError('Unexpected Google translate response');
    }
    final buf = StringBuffer();
    for (final seg in segments) {
      if (seg is! List || seg.isEmpty) continue;
      final t = seg.first;
      if (t is String) buf.write(t);
    }
    return buf.toString().trim();
  }

  Future<String> _getBingToken() async {
    final now = DateTime.now();
    final token = _bingToken;
    final expiresAt = _bingTokenExpiresAt;
    if (token != null && expiresAt != null) {
      if (expiresAt.isAfter(now.add(const Duration(seconds: 60)))) {
        return token;
      }
    }

    final uri = Uri.https('edge.microsoft.com', '/translate/auth');
    final res = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    final next = (res.data ?? '').trim();
    if (next.isEmpty) throw StateError('Failed to get Bing auth token');

    DateTime? exp;
    try {
      final parts = next.split('.');
      if (parts.length >= 2) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final bytes = base64Url.decode(normalized);
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map) {
          final rawExp = decoded['exp'];
          final expSec = rawExp is num ? rawExp.toInt() : null;
          if (expSec != null) {
            exp = DateTime.fromMillisecondsSinceEpoch(
              expSec * 1000,
              isUtc: true,
            ).toLocal();
          }
        }
      }
    } catch (_) {
      // ignore: best-effort token expiry parsing
    }

    _bingToken = next;
    _bingTokenExpiresAt = exp ?? now.add(const Duration(minutes: 5));
    return next;
  }

  Future<String> _translateBingWeb(
    String text, {
    required String targetLanguageTag,
  }) async {
    final token = await _getBingToken();
    final to = _bingLangCode(targetLanguageTag);
    final uri = Uri.https(
      'api-edge.cognitive.microsofttranslator.com',
      '/translate',
      <String, String>{'api-version': '3.0', 'to': to},
    );
    final res = await _dio.postUri<List<dynamic>>(
      uri,
      data: [
        <String, Object?>{'Text': text},
      ],
      options: Options(
        headers: <String, Object?>{'Authorization': 'Bearer $token'},
        responseType: ResponseType.json,
      ),
    );
    final data = res.data;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        final translations = first['translations'];
        if (translations is List && translations.isNotEmpty) {
          final t0 = translations.first;
          if (t0 is Map) {
            final out = t0['text'];
            if (out is String) return out.trim();
          }
        }
      }
    }
    throw StateError('Unexpected Bing translate response');
  }

  Future<String> _translateBaiduApi(
    TranslationAiSecretStore secrets,
    String text, {
    required String targetLanguageTag,
  }) async {
    final creds = await secrets.getBaiduCredentials();
    if (creds == null) throw StateError('Baidu credentials not set');

    final salt = Random.secure().nextInt(1 << 30).toString();
    final to = _baiduLangCode(targetLanguageTag);
    final sign = md5
        .convert(utf8.encode('${creds.appId}$text$salt${creds.appKey}'))
        .toString();

    final uri = Uri.https('fanyi-api.baidu.com', '/api/trans/vip/translate');
    final res = await _dio.postUri<String>(
      uri,
      data: <String, Object?>{
        'q': text,
        'from': 'auto',
        'to': to,
        'appid': creds.appId,
        'salt': salt,
        'sign': sign,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
      ),
    );
    final raw = res.data ?? '';
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw StateError('Unexpected Baidu response');

    final errorCode = decoded['error_code'];
    if (errorCode != null) {
      final msg = decoded['error_msg'];
      throw StateError('Baidu error: $errorCode ${msg ?? ''}'.trim());
    }

    final results = decoded['trans_result'];
    if (results is List) {
      final buf = StringBuffer();
      for (final item in results) {
        if (item is! Map) continue;
        final dst = item['dst'];
        if (dst is String && dst.trim().isNotEmpty) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(dst.trim());
        }
      }
      final out = buf.toString().trim();
      if (out.isNotEmpty) return out;
    }

    throw StateError('Unexpected Baidu response');
  }

  Future<String> _translateDeepLApi(
    TranslationAiSecretStore secrets,
    TranslationAiSettings settings,
    String text, {
    required String targetLanguageTag,
  }) async {
    final apiKey = await secrets.getDeepLApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('DeepL API key not set');
    }

    final endpoint = settings.deepL.endpoint;
    final uri = switch (endpoint) {
      DeepLEndpoint.free => Uri.https('api-free.deepl.com', '/v2/translate'),
      DeepLEndpoint.pro => Uri.https('api.deepl.com', '/v2/translate'),
    };
    final target = _deeplLangCode(targetLanguageTag);

    final res = await _dio.postUri<Map<String, Object?>>(
      uri,
      data: <String, Object?>{'text': text, 'target_lang': target},
      options: Options(
        headers: <String, Object?>{'Authorization': 'DeepL-Auth-Key $apiKey'},
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
    );
    final data = res.data;
    if (data == null) throw StateError('Empty response');
    final translations = data['translations'];
    if (translations is List && translations.isNotEmpty) {
      final t0 = translations.first;
      if (t0 is Map) {
        final out = t0['text'];
        if (out is String) return out.trim();
      }
    }
    throw StateError('Unexpected DeepL response');
  }

  Future<String> _translateDeepLX(
    TranslationAiSettings settings,
    String text, {
    required String targetLanguageTag,
  }) async {
    final baseUrl = settings.deepLX.baseUrl.trim();
    if (baseUrl.isEmpty) throw StateError('DeepLX baseUrl not set');
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final uri = base.resolve('translate');
    final target = _deeplLangCode(targetLanguageTag);

    final res = await _dio.postUri<Object?>(
      uri,
      data: <String, Object?>{
        'text': text,
        'source_lang': 'auto',
        'target_lang': target,
      },
      options: Options(
        headers: const <String, Object?>{'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    final data = res.data;
    if (data is Map) {
      final d = data['data'];
      if (d is String && d.trim().isNotEmpty) return d.trim();
      final t = data['translation'];
      if (t is String && t.trim().isNotEmpty) return t.trim();
      final translations = data['translations'];
      if (translations is List && translations.isNotEmpty) {
        final t0 = translations.first;
        if (t0 is Map) {
          final out = t0['text'];
          if (out is String) return out.trim();
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    throw StateError('Unexpected DeepLX response');
  }
}
