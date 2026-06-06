import 'package:dio/dio.dart';

import 'google_reader_client.dart';
import 'google_reader_provider_profile.dart';
import '../remote_article_action_executor.dart';

class GoogleReaderProbeResult {
  const GoogleReaderProbeResult({
    required this.profile,
    required this.normalizedBaseUrl,
    this.displayName,
  });

  final GoogleReaderProviderProfile profile;
  final String normalizedBaseUrl;
  final String? displayName;
}

class GoogleReaderProbeException implements Exception {
  const GoogleReaderProbeException(this.message);

  final String message;

  @override
  String toString() => 'GoogleReaderProbeException($message)';
}

class GoogleReaderConnectionProbe {
  const GoogleReaderConnectionProbe({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<GoogleReaderProbeResult> probe({
    required String baseUrl,
    required String username,
    required String password,
    String? profileId,
  }) async {
    final profiles = _profilesFor(profileId);
    Object? lastError;
    for (final profile in profiles) {
      try {
        return await _probeProfile(
          baseUrl: baseUrl,
          username: username,
          password: password,
          profile: profile,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw GoogleReaderProbeException(_sanitizedFailureMessage(lastError));
  }

  List<GoogleReaderProviderProfile> _profilesFor(String? profileId) {
    final trimmed = profileId?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == GoogleReaderProviderProfiles.autoId) {
      return GoogleReaderProviderProfiles.probeOrder;
    }
    return [GoogleReaderProviderProfiles.fromId(trimmed)];
  }

  Future<GoogleReaderProbeResult> _probeProfile({
    required String baseUrl,
    required String username,
    required String password,
    required GoogleReaderProviderProfile profile,
  }) async {
    final client = GoogleReaderClient(
      dio: _dio,
      baseUrl: baseUrl,
      profile: profile,
      username: username,
      password: password,
    );
    await client.ensureAuthenticated();

    Map<String, Object?> userInfo = const <String, Object?>{};
    try {
      userInfo = await client.userInfo();
    } catch (_) {
      final subscriptions = await client.subscriptionList();
      if (subscriptions.isEmpty) {
        // Empty subscription lists are valid, but reaching the endpoint is enough.
        // The request above would have thrown if the endpoint/auth were invalid.
      }
    }

    await client.token();
    await client.streamItemIds(
      streamId: GoogleReaderRemoteArticleActionExecutor.readingListState,
      count: 1,
    );

    return GoogleReaderProbeResult(
      profile: profile,
      normalizedBaseUrl: client.normalizedBaseUrl,
      displayName: _displayNameFromUserInfo(userInfo),
    );
  }

  static String? _displayNameFromUserInfo(Map<String, Object?> userInfo) {
    for (final key in const ['userName', 'userEmail', 'email', 'displayName']) {
      final value = userInfo[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _sanitizedFailureMessage(Object? error) {
    if (error is GoogleReaderProbeException) return error.message;
    if (error is GoogleReaderAuthException) {
      return 'Google Reader authentication failed.';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) {
        return 'Google Reader connection failed with HTTP $status.';
      }
    }
    return 'Google Reader connection failed.';
  }
}
