import 'package:dio/dio.dart';

class RssClient {
  RssClient(this._dio);

  final Dio _dio;

  Future<String> fetchXml(String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'application/rss+xml, application/atom+xml, text/xml, */*',
          'User-Agent':
              'FlutterReader/0.1 (+https://example.invalid) Dart/Dio',
        },
      ),
    );
    return res.data ?? '';
  }
}

