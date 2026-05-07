import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';
import 'account.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String accountId, String name) => 'fleur:$accountId:$name';

  Future<void> setApiToken(String accountId, AccountType type, String token) {
    final trimmed = token.trim();
    return _runStorageOperation<void>(
      operation: 'setApiToken',
      accountId: accountId,
      accountType: type,
      credentialKind: 'apiToken',
      action: () => _storage.write(
        key: _key(accountId, '${type.wire}_api_token'),
        value: trimmed,
      ),
    );
  }

  Future<String?> getApiToken(String accountId, AccountType type) {
    return _runStorageOperation<String?>(
      operation: 'getApiToken',
      accountId: accountId,
      accountType: type,
      credentialKind: 'apiToken',
      action: () =>
          _storage.read(key: _key(accountId, '${type.wire}_api_token')),
    );
  }

  Future<void> deleteApiToken(String accountId, AccountType type) {
    return _runStorageOperation<void>(
      operation: 'deleteApiToken',
      accountId: accountId,
      accountType: type,
      credentialKind: 'apiToken',
      action: () =>
          _storage.delete(key: _key(accountId, '${type.wire}_api_token')),
    );
  }

  Future<void> setBasicAuth(
    String accountId,
    AccountType type, {
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p = password;
    await _runStorageOperation<void>(
      operation: 'setBasicAuth',
      accountId: accountId,
      accountType: type,
      credentialKind: 'basicAuth',
      action: () async {
        await _storage.write(
          key: _key(accountId, '${type.wire}_username'),
          value: u,
        );
        await _storage.write(
          key: _key(accountId, '${type.wire}_password'),
          value: p,
        );
      },
    );
  }

  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return _runStorageOperation<({String username, String password})?>(
      operation: 'getBasicAuth',
      accountId: accountId,
      accountType: type,
      credentialKind: 'basicAuth',
      action: () async {
        final u = await _storage.read(
          key: _key(accountId, '${type.wire}_username'),
        );
        final p = await _storage.read(
          key: _key(accountId, '${type.wire}_password'),
        );
        if (u == null || u.trim().isEmpty) return null;
        if (p == null) return null;
        return (username: u.trim(), password: p);
      },
    );
  }

  Future<void> deleteBasicAuth(String accountId, AccountType type) async {
    await _runStorageOperation<void>(
      operation: 'deleteBasicAuth',
      accountId: accountId,
      accountType: type,
      credentialKind: 'basicAuth',
      action: () async {
        await _storage.delete(key: _key(accountId, '${type.wire}_username'));
        await _storage.delete(key: _key(accountId, '${type.wire}_password'));
      },
    );
  }

  Future<T> _runStorageOperation<T>({
    required String operation,
    required String accountId,
    required AccountType accountType,
    required String credentialKind,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (e, st) {
      _logStorageFailure(
        operation: operation,
        accountId: accountId,
        accountType: accountType,
        credentialKind: credentialKind,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static void _logStorageFailure({
    required String operation,
    required String accountId,
    required AccountType accountType,
    required String credentialKind,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.e(
      'Credential storage operation failed',
      tag: 'credential',
      error: error,
      stackTrace: stackTrace,
      context: _storageFailureContext(
        operation: operation,
        accountId: accountId,
        accountType: accountType,
        credentialKind: credentialKind,
        error: error,
      ),
    );
  }

  static Map<String, Object?> _storageFailureContext({
    required String operation,
    required String accountId,
    required AccountType accountType,
    required String credentialKind,
    required Object error,
  }) {
    return <String, Object?>{
      'operation': operation,
      'accountId': accountId,
      'accountType': accountType.wire,
      'credentialKind': credentialKind,
      if (error is PlatformException) ...<String, Object?>{
        'platformCode': error.code,
        'platformMessage': error.message,
      },
    };
  }
}
