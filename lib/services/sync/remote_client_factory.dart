import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../accounts/account.dart';
import '../accounts/credential_store.dart';
import 'fever/fever_client.dart';
import 'miniflux/miniflux_client.dart';

class RemoteClientFactory {
  const RemoteClientFactory({
    required Dio dio,
    required CredentialStore credentials,
  }) : _dio = dio,
       _credentials = credentials;

  final Dio _dio;
  final CredentialStore _credentials;

  Future<MinifluxClient> miniflux(Account account) async {
    final baseUrl = (account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) {
      throw StateError('Miniflux baseUrl is empty');
    }

    final token = await _credentials.getApiToken(
      account.id,
      AccountType.miniflux,
    );
    if (token != null && token.trim().isNotEmpty) {
      return MinifluxClient(
        dio: _dio,
        baseUrl: baseUrl,
        apiToken: token.trim(),
      );
    }

    final basic = await _credentials.getBasicAuth(
      account.id,
      AccountType.miniflux,
    );
    if (basic != null) {
      return MinifluxClient(
        dio: _dio,
        baseUrl: baseUrl,
        username: basic.username,
        password: basic.password,
      );
    }

    throw StateError('Miniflux credentials are missing');
  }

  Future<MinifluxClient?> minifluxOrNull(Account account) async {
    final baseUrl = (account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) return null;

    final token = await _credentials.getApiToken(
      account.id,
      AccountType.miniflux,
    );
    if (token != null && token.trim().isNotEmpty) {
      return MinifluxClient(
        dio: _dio,
        baseUrl: baseUrl,
        apiToken: token.trim(),
      );
    }

    final basic = await _credentials.getBasicAuth(
      account.id,
      AccountType.miniflux,
    );
    if (basic == null) return null;
    return MinifluxClient(
      dio: _dio,
      baseUrl: baseUrl,
      username: basic.username,
      password: basic.password,
    );
  }

  Future<FeverClient> fever(Account account) async {
    final baseUrl = (account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) {
      throw StateError('Fever baseUrl is empty');
    }

    final token = await _credentials.getApiToken(account.id, AccountType.fever);
    if (token != null && token.trim().isNotEmpty) {
      return FeverClient(dio: _dio, baseUrl: baseUrl, apiKey: token.trim());
    }

    final basic = await _credentials.getBasicAuth(
      account.id,
      AccountType.fever,
    );
    if (basic != null) {
      return FeverClient(
        dio: _dio,
        baseUrl: baseUrl,
        apiKey: _feverApiKeyFromBasicAuth(basic),
      );
    }

    throw StateError('Fever credentials are missing');
  }

  Future<FeverClient?> feverOrNull(Account account) async {
    final baseUrl = (account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) return null;

    final token = await _credentials.getApiToken(account.id, AccountType.fever);
    if (token != null && token.trim().isNotEmpty) {
      return FeverClient(dio: _dio, baseUrl: baseUrl, apiKey: token.trim());
    }

    final basic = await _credentials.getBasicAuth(
      account.id,
      AccountType.fever,
    );
    if (basic == null) return null;
    return FeverClient(
      dio: _dio,
      baseUrl: baseUrl,
      apiKey: _feverApiKeyFromBasicAuth(basic),
    );
  }

  static String _feverApiKeyFromBasicAuth(
    ({String username, String password}) basic,
  ) {
    return md5
        .convert(utf8.encode('${basic.username}:${basic.password}'))
        .toString();
  }
}
