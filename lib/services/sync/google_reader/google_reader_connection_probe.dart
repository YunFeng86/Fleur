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
  const GoogleReaderProbeException(
    this.message, {
    this.profileId,
    this.operation,
    this.host,
    this.path,
    this.statusCode,
    this.dioType,
  });

  final String message;
  final String? profileId;
  final String? operation;
  final String? host;
  final String? path;
  final int? statusCode;
  final String? dioType;

  Map<String, Object?> get logContext => <String, Object?>{
    'profileId': profileId,
    'probeOperation': operation,
    'host': host,
    'path': path,
    'statusCode': statusCode,
    'dioType': dioType,
  };

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
    if (lastError is GoogleReaderProbeException) throw lastError;
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
    late final GoogleReaderClient client;
    try {
      client = GoogleReaderClient(
        dio: _dio,
        baseUrl: baseUrl,
        profile: profile,
        username: username,
        password: password,
      );
    } catch (e) {
      throw _probeExceptionFrom(e, profile: profile, operation: 'buildClient');
    }
    await _runProbeOperation<void>(
      profile: profile,
      operation: 'clientLogin',
      action: () => client.ensureAuthenticated(),
    );

    Map<String, Object?> userInfo = const <String, Object?>{};
    try {
      userInfo = await _runProbeOperation<Map<String, Object?>>(
        profile: profile,
        operation: 'userInfo',
        action: client.userInfo,
      );
    } on GoogleReaderProbeException {
      final subscriptions =
          await _runProbeOperation<List<Map<String, Object?>>>(
            profile: profile,
            operation: 'subscriptionList',
            action: client.subscriptionList,
          );
      if (subscriptions.isEmpty) {
        // Empty subscription lists are valid, but reaching the endpoint is enough.
        // The request above would have thrown if the endpoint/auth were invalid.
      }
    }

    await _runProbeOperation<String>(
      profile: profile,
      operation: 'token',
      action: client.token,
    );
    await _runProbeOperation<GoogleReaderItemIdsPage>(
      profile: profile,
      operation: 'streamItemIds',
      action: () => client.streamItemIds(
        streamId: GoogleReaderRemoteArticleActionExecutor.readingListState,
        count: 1,
      ),
    );

    return GoogleReaderProbeResult(
      profile: profile,
      normalizedBaseUrl: client.normalizedBaseUrl,
      displayName: _displayNameFromUserInfo(userInfo),
    );
  }

  static Future<T> _runProbeOperation<T>({
    required GoogleReaderProviderProfile profile,
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (e) {
      throw _probeExceptionFrom(e, profile: profile, operation: operation);
    }
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

  static GoogleReaderProbeException _probeExceptionFrom(
    Object error, {
    required GoogleReaderProviderProfile profile,
    required String operation,
  }) {
    if (error is GoogleReaderProbeException) {
      return GoogleReaderProbeException(
        error.message,
        profileId: error.profileId ?? profile.id,
        operation: error.operation ?? operation,
        host: error.host,
        path: error.path,
        statusCode: error.statusCode,
        dioType: error.dioType,
      );
    }
    if (error is DioException) {
      final request = error.requestOptions;
      final uri = request.uri;
      final status = error.response?.statusCode;
      return GoogleReaderProbeException(
        _messageForDioFailure(status),
        profileId: profile.id,
        operation: operation,
        host: uri.host.isEmpty ? null : uri.host,
        path: uri.path.isEmpty ? '/' : uri.path,
        statusCode: status,
        dioType: error.type.name,
      );
    }
    if (error is GoogleReaderAuthException) {
      return GoogleReaderProbeException(
        'Google Reader authentication failed.',
        profileId: profile.id,
        operation: operation,
      );
    }
    if (error is ArgumentError) {
      return GoogleReaderProbeException(
        'Google Reader base URL is invalid.',
        profileId: profile.id,
        operation: operation,
      );
    }
    return GoogleReaderProbeException(
      'Google Reader connection failed.',
      profileId: profile.id,
      operation: operation,
    );
  }

  static String _messageForDioFailure(int? status) {
    if (status == null) return 'Google Reader connection failed.';
    if (status == 401 || status == 403) {
      return 'Google Reader authentication failed with HTTP $status.';
    }
    return 'Google Reader connection failed with HTTP $status.';
  }
}
