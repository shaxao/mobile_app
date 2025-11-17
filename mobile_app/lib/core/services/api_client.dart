import 'package:dio/dio.dart';
import '../constants/config.dart';

class ApiClient {
  ApiClient._();
  static final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBase));

  static Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>(path, queryParameters: query);
  }

  static Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? query}) {
    return _dio.post<T>(path, data: data, queryParameters: query);
  }

  static Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? query}) {
    return _dio.delete<T>(path, data: data, queryParameters: query);
  }
}