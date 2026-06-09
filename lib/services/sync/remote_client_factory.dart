import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../accounts/account.dart';
import '../accounts/credential_store.dart';
import 'fever/fever_client.dart';
import 'google_reader/google_reader_client.dart';
import 'google_reader/google_reader_provider_profile.dart';
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
    final baseUrl = _requireBaseUrl(account, backendName: 'Miniflux');
    final client = await _minifluxClientOrNull(account, baseUrl);
    if (client == null) throw StateError('Miniflux credentials are missing');
    return client;
  }

  Future<MinifluxClient?> minifluxOrNull(Account account) async {
    final baseUrl = _trimmedBaseUrl(account);
    if (baseUrl.isEmpty) return null;
    return _minifluxClientOrNull(account, baseUrl);
  }

  Future<MinifluxClient?> _minifluxClientOrNull(
    Account account,
    String baseUrl,
  ) async {
    final token = await _apiTokenOrNull(account, AccountType.miniflux);
    if (token != null) {
      return MinifluxClient(dio: _dio, baseUrl: baseUrl, apiToken: token);
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
    final baseUrl = _requireBaseUrl(account, backendName: 'Fever');
    final client = await _feverClientOrNull(account, baseUrl);
    if (client == null) throw StateError('Fever credentials are missing');
    return client;
  }

  Future<FeverClient?> feverOrNull(Account account) async {
    final baseUrl = _trimmedBaseUrl(account);
    if (baseUrl.isEmpty) return null;
    return _feverClientOrNull(account, baseUrl);
  }

  Future<FeverClient?> _feverClientOrNull(
    Account account,
    String baseUrl,
  ) async {
    final token = await _apiTokenOrNull(account, AccountType.fever);
    if (token != null) {
      return FeverClient(dio: _dio, baseUrl: baseUrl, apiKey: token);
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

  Future<GoogleReaderClient> googleReader(Account account) async {
    final baseUrl = _requireBaseUrl(account, backendName: 'Google Reader API');
    final client = await _googleReaderClientOrNull(account, baseUrl);
    if (client == null) {
      throw StateError('Google Reader API credentials are missing');
    }
    return client;
  }

  Future<GoogleReaderClient?> googleReaderOrNull(Account account) async {
    final baseUrl = _trimmedBaseUrl(account);
    if (baseUrl.isEmpty) return null;
    return _googleReaderClientOrNull(account, baseUrl);
  }

  Future<GoogleReaderClient?> _googleReaderClientOrNull(
    Account account,
    String baseUrl,
  ) async {
    final token = await _apiTokenOrNull(account, AccountType.googleReader);
    final profile = GoogleReaderProviderProfiles.forAccount(account);
    if (token != null) {
      return GoogleReaderClient(
        dio: _dio,
        baseUrl: baseUrl,
        profile: profile,
        authToken: token,
      );
    }

    final basic = await _credentials.getBasicAuth(
      account.id,
      AccountType.googleReader,
    );
    if (basic == null) return null;
    return GoogleReaderClient(
      dio: _dio,
      baseUrl: baseUrl,
      profile: profile,
      username: basic.username,
      password: basic.password,
    );
  }

  String _requireBaseUrl(Account account, {required String backendName}) {
    final baseUrl = _trimmedBaseUrl(account);
    if (baseUrl.isEmpty) {
      throw StateError('$backendName baseUrl is empty');
    }
    return baseUrl;
  }

  String _trimmedBaseUrl(Account account) {
    return (account.baseUrl ?? '').trim();
  }

  Future<String?> _apiTokenOrNull(Account account, AccountType type) async {
    final token = await _credentials.getApiToken(account.id, type);
    final trimmed = token?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _feverApiKeyFromBasicAuth(
    ({String username, String password}) basic,
  ) {
    return md5
        .convert(utf8.encode('${basic.username}:${basic.password}'))
        .toString();
  }
}
