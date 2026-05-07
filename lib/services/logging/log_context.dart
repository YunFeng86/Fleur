import 'package:dio/dio.dart';

Map<String, Object?> logContextForDioException(
  DioException error, {
  Map<String, Object?>? extra,
}) {
  final request = error.requestOptions;
  final uri = request.uri;
  return <String, Object?>{
    ...?extra,
    'dioType': error.type.name,
    'host': uri.host.isEmpty ? null : uri.host,
    'method': request.method,
    'path': uri.path.isEmpty ? '/' : uri.path,
    'statusCode': error.response?.statusCode,
  };
}

Map<String, Object?> logContextForUri(
  Uri uri, {
  String? method,
  Map<String, Object?>? extra,
}) {
  return <String, Object?>{
    ...?extra,
    'host': uri.host.isEmpty ? null : uri.host,
    'method': method,
    'path': uri.path.isEmpty ? '/' : uri.path,
  };
}
