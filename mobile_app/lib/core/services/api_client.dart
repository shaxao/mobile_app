import 'package:dio/dio.dart';
import '../constants/config.dart';

class ApiClient {
  ApiClient._();
  static final Dio _dio = Dio();

  static String _buildUrl(String path) {
    final base = (AppConfig.apiBase).trim();
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return '$b/$p';
  }

  static Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>(_buildUrl(path), queryParameters: query);
  }

  static Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? query}) {
    return _dio.post<T>(_buildUrl(path), data: data, queryParameters: query);
  }

  static Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? query}) {
    return _dio.delete<T>(_buildUrl(path), data: data, queryParameters: query);
  }
}
