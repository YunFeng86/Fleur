import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/context_extensions.dart';
import '../application/subscription_structure_commands.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../services/logging/app_logger.dart';

bool isRemoteStructureConnectivityFailure(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        final cause = error.error;
        return cause is SocketException || cause is TimeoutException;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }
  return error is SocketException || error is TimeoutException;
}

bool isRemoteStructureCredentialFailure(Object error) {
  if (error is DioException && error.type == DioExceptionType.badResponse) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }
  return error is StateError &&
      error.toString().contains('credentials are missing');
}

bool isRemoteStructureTargetResolutionFailure(Object error) {
  if (error is DioException && error.type == DioExceptionType.badResponse) {
    return error.response?.statusCode == 404;
  }
  if (error is! StateError) return false;
  final message = error.toString();
  return message.contains('Remote feed not found') ||
      message.contains('Remote category not found') ||
      message.contains('Local feed not found') ||
      message.contains('Local category not found');
}

bool isRemoteStructureRejectedCommand(Object error) {
  if (error is ArgumentError) return true;
  if (error is DioException && error.type == DioExceptionType.badResponse) {
    final status = error.response?.statusCode;
    if (status == null) return false;
    return status >= 400 &&
        status < 500 &&
        status != 401 &&
        status != 403 &&
        status != 404;
  }
  return false;
}

String remoteStructureFailureMessage(AppLocalizations l10n, Object error) {
  if (isRemoteStructureConnectivityFailure(error)) {
    return l10n.remoteCommandRequiresConnectivity;
  }
  if (isRemoteStructureCredentialFailure(error)) {
    return l10n.remoteCommandRequiresAuthentication;
  }
  if (isRemoteStructureTargetResolutionFailure(error)) {
    return l10n.remoteCommandNeedsRefresh;
  }
  if (isRemoteStructureRejectedCommand(error)) {
    return l10n.remoteCommandRejected;
  }
  return l10n.remoteCommandUnavailable;
}

void showUnsupportedRemoteCommand(BuildContext context, AppLocalizations l10n) {
  if (!context.mounted) return;
  context.showErrorMessage(l10n.remoteCommandNotSupported);
}

void showRemoteStructureFailure(
  BuildContext context,
  AppLocalizations l10n,
  Object error,
) {
  if (!context.mounted) return;
  context.showErrorMessage(remoteStructureFailureMessage(l10n, error));
}

void logSubscriptionFailure(
  WidgetRef ref,
  String operation,
  Object error, [
  StackTrace? stackTrace,
]) {
  final account = ref.read(activeAccountProvider);
  final capabilities = ref.read(backendCapabilitiesProvider);
  AppLogger.w(
    'Subscription operation failed',
    tag: 'subscription',
    error: error,
    stackTrace: stackTrace,
    context: subscriptionStructureFailureContext(
      account,
      capabilities,
      error,
      operation,
    ),
  );
}
