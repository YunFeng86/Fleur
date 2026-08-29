import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/network/size_limited_adapter.dart';

Dio createAppDio({
  int maxResponseBytes = SizeLimitedHttpClientAdapter.defaultMaxBytes,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );
  dio.httpClientAdapter = SizeLimitedHttpClientAdapter(
    inner: adapter ?? dio.httpClientAdapter,
    maxBytes: maxResponseBytes,
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }
  return dio;
}

final dioProvider = Provider<Dio>((ref) => createAppDio());
