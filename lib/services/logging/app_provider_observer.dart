import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';

class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.e(
      'Provider failed',
      tag: 'provider',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'provider': provider.name ?? provider.toString(),
        'providerType': provider.runtimeType.toString(),
      },
    );
  }
}
