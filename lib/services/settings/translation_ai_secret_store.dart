import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

class TranslationAiSecretStore {
  TranslationAiSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _prefix = 'fleur:translation_ai';

  String _key(String name) => '$_prefix:$name';

  String _aiServiceKey(String serviceId, String name) =>
      '$_prefix:ai_service:$serviceId:$name';

  Future<void> setBaiduCredentials({
    required String appId,
    required String appKey,
  }) async {
    final id = appId.trim();
    final key = appKey;
    await _runStorageOperation<void>(
      operation: 'setBaiduCredentials',
      credentialKind: 'baiduCredentials',
      action: () async {
        await _storage.write(key: _key('baidu:app_id'), value: id);
        await _storage.write(key: _key('baidu:app_key'), value: key);
      },
    );
  }

  Future<({String appId, String appKey})?> getBaiduCredentials() async {
    return _runStorageOperation<({String appId, String appKey})?>(
      operation: 'getBaiduCredentials',
      credentialKind: 'baiduCredentials',
      action: () async {
        final appId = await _storage.read(key: _key('baidu:app_id'));
        final appKey = await _storage.read(key: _key('baidu:app_key'));
        if (appId == null || appId.trim().isEmpty) return null;
        if (appKey == null || appKey.isEmpty) return null;
        return (appId: appId.trim(), appKey: appKey);
      },
    );
  }

  Future<void> deleteBaiduCredentials() async {
    await _runStorageOperation<void>(
      operation: 'deleteBaiduCredentials',
      credentialKind: 'baiduCredentials',
      action: () async {
        await _storage.delete(key: _key('baidu:app_id'));
        await _storage.delete(key: _key('baidu:app_key'));
      },
    );
  }

  Future<void> setDeepLApiKey(String apiKey) {
    final trimmed = apiKey.trim();
    return _runStorageOperation<void>(
      operation: 'setDeepLApiKey',
      credentialKind: 'deeplApiKey',
      action: () => _storage.write(key: _key('deepl:api_key'), value: trimmed),
    );
  }

  Future<String?> getDeepLApiKey() async {
    return _runStorageOperation<String?>(
      operation: 'getDeepLApiKey',
      credentialKind: 'deeplApiKey',
      action: () async {
        final v = await _storage.read(key: _key('deepl:api_key'));
        final trimmed = (v ?? '').trim();
        return trimmed.isEmpty ? null : trimmed;
      },
    );
  }

  Future<void> deleteDeepLApiKey() {
    return _runStorageOperation<void>(
      operation: 'deleteDeepLApiKey',
      credentialKind: 'deeplApiKey',
      action: () => _storage.delete(key: _key('deepl:api_key')),
    );
  }

  Future<void> setAiServiceApiKey(String serviceId, String apiKey) {
    final trimmed = apiKey.trim();
    return _runStorageOperation<void>(
      operation: 'setAiServiceApiKey',
      credentialKind: 'aiServiceApiKey',
      serviceId: serviceId,
      action: () => _storage.write(
        key: _aiServiceKey(serviceId, 'api_key'),
        value: trimmed,
      ),
    );
  }

  Future<String?> getAiServiceApiKey(String serviceId) async {
    return _runStorageOperation<String?>(
      operation: 'getAiServiceApiKey',
      credentialKind: 'aiServiceApiKey',
      serviceId: serviceId,
      action: () async {
        final v = await _storage.read(key: _aiServiceKey(serviceId, 'api_key'));
        final trimmed = (v ?? '').trim();
        return trimmed.isEmpty ? null : trimmed;
      },
    );
  }

  Future<void> deleteAiServiceApiKey(String serviceId) {
    return _runStorageOperation<void>(
      operation: 'deleteAiServiceApiKey',
      credentialKind: 'aiServiceApiKey',
      serviceId: serviceId,
      action: () => _storage.delete(key: _aiServiceKey(serviceId, 'api_key')),
    );
  }

  Future<T> _runStorageOperation<T>({
    required String operation,
    required String credentialKind,
    required Future<T> Function() action,
    String? serviceId,
  }) async {
    try {
      return await action();
    } catch (e, st) {
      _logStorageFailure(
        operation: operation,
        credentialKind: credentialKind,
        serviceId: serviceId,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static void _logStorageFailure({
    required String operation,
    required String credentialKind,
    required Object error,
    required StackTrace stackTrace,
    String? serviceId,
  }) {
    AppLogger.e(
      'Translation credential storage operation failed',
      tag: 'credential',
      error: error,
      stackTrace: stackTrace,
      context: _storageFailureContext(
        operation: operation,
        credentialKind: credentialKind,
        serviceId: serviceId,
        error: error,
      ),
    );
  }

  static Map<String, Object?> _storageFailureContext({
    required String operation,
    required String credentialKind,
    required Object error,
    String? serviceId,
  }) {
    return <String, Object?>{
      'operation': operation,
      'service': 'translation_ai',
      'credentialKind': credentialKind,
      'serviceId': serviceId,
      if (error is PlatformException) ...<String, Object?>{
        'platformCode': error.code,
        'platformMessage': error.message,
      },
    };
  }
}
