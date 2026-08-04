import 'dart:developer';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// 共享 Dio 实例，带 token 拦截器
class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio get instance {
    if (_instance != null) return _instance!;
    _instance = _create();
    return _instance!;
  }

  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          // Token 过期，清理本地登录态
          _token = null;
        }
        handler.next(e);
      },
    ));

    return dio;
  }

  static void dispose() {
    _instance?.close();
    _instance = null;
    _token = null;
  }
}