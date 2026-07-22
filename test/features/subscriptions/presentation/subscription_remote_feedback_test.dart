import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/subscriptions/presentation/subscription_remote_feedback.dart';
import 'package:fleur/l10n/app_localizations_en.dart';

void main() {
  test('maps connectivity errors to actionable feedback', () {
    final message = remoteStructureFailureMessage(
      AppLocalizationsEn(),
      DioException(
        requestOptions: RequestOptions(path: '/v1/feeds/91'),
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      ),
    );

    expect(message, 'This action requires connectivity to the remote service.');
  });

  test('keeps credential failures out of connectivity feedback', () {
    final request = RequestOptions(path: '/v1/feeds/91');
    final message = remoteStructureFailureMessage(
      AppLocalizationsEn(),
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: request,
          statusCode: 401,
          data: const <String, Object?>{'error_message': 'Unauthorized'},
        ),
      ),
    );

    expect(
      message,
      'The remote service rejected the current account credentials. Check the account settings and try again.',
    );
  });

  test('maps target drift to sync feedback', () {
    final message = remoteStructureFailureMessage(
      AppLocalizationsEn(),
      StateError('Remote feed not found for url: https://example.com/feed.xml'),
    );

    expect(
      message,
      'The remote service could not match the current feed or category. Sync and try again.',
    );
  });

  test('maps server errors to remote availability feedback', () {
    final request = RequestOptions(path: '/v1/feeds/91');
    final message = remoteStructureFailureMessage(
      AppLocalizationsEn(),
      DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: request,
          statusCode: 503,
          data: const <String, Object?>{'error_message': 'Service unavailable'},
        ),
      ),
    );

    expect(
      message,
      'The remote service could not complete this action right now. Try again later.',
    );
  });
}
