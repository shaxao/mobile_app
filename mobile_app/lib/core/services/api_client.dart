import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/config.dart';

class ApiClient {
  ApiClient._();
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  static String _base = AppConfig.apiBase;
  static Future<void> initFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('api_base');
    if (v != null && v.isNotEmpty) {
      _base = v;
    }
  }

  static void setBase(String base) {
    _base = base;
  }

  static String _buildUrl(String path) {
    final p0 = (path).trim();
    if (p0.startsWith('http://') || p0.startsWith('https://')) {
      return p0;
    }
    final base = (_base).trim();
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = p0.startsWith('/') ? p0.substring(1) : p0;
    return '$b/$p';
  }

  static String absoluteUrl(String path) {
    return _buildUrl(path);
  }

  static String serverRoot() {
    final base = (_base).trim();
    final idx = base.indexOf('/api/v1');
    if (idx != -1) {
      return base.substring(0, idx);
    }
    return base;
  }

  static Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _dio.get<T>(_buildUrl(path), queryParameters: query);
  }

  static Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.post<T>(
      _buildUrl(path),
      data: data,
      queryParameters: query,
      options: options,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  static Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _dio.put<T>(_buildUrl(path), data: data, queryParameters: query);
  }

  static Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return _dio.delete<T>(_buildUrl(path), data: data, queryParameters: query);
  }
}
