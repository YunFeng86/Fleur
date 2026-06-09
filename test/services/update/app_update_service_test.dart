import 'package:dio/dio.dart';
import 'package:fleur/services/update/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports update when remote version is newer', () async {
    final service = AppUpdateService(
      dio: _buildDio({
        'GET /Fleur/updates/stable/latest.json': (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: {
                'schemaVersion': 1,
                'channel': 'stable',
                'version': '0.1.5',
                'tag': 'v0.1.5',
                'releaseUrl':
                    'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
                'notes': {'en': '- Fixed'},
              },
            ),
          );
        },
      }),
      manifestUri: Uri.parse(
        'https://zeyrme.github.io/Fleur/updates/stable/latest.json',
      ),
    );

    final result = await service.checkLatest(currentVersion: '0.1.2');

    expect(result.isUpdateAvailable, isTrue);
    expect(result.manifest.version, '0.1.5');
  });

  test('reports up to date when versions match', () async {
    final service = AppUpdateService(
      dio: _buildDio({
        'GET /latest.json': (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: {
                'schemaVersion': 1,
                'channel': 'stable',
                'version': '0.1.5',
                'tag': 'v0.1.5',
                'releaseUrl':
                    'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
                'notes': {'en': '- Fixed'},
              },
            ),
          );
        },
      }),
      manifestUri: Uri.parse('https://updates.example.com/latest.json'),
    );

    final result = await service.checkLatest(currentVersion: '0.1.5');

    expect(result.isUpdateAvailable, isFalse);
  });
}

Dio _buildDio(
  Map<String, void Function(RequestOptions, RequestInterceptorHandler)> routes,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = '${options.method} ${options.uri.path}';
        final route = routes[key];
        if (route != null) {
          route(options, handler);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'unexpected request: $key',
          ),
        );
      },
    ),
  );
  return dio;
}
