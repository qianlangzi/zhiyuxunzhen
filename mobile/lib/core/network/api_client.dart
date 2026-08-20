import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// 共享 Dio 实例，带 token 拦截器
///
/// token 同时持久化到本地（[SharedPreferences]），冷启动时由
/// [restoreToken] 恢复，避免杀进程重开后所有受保护接口因缺
/// Authorization 头而全量 401。
class ApiClient {
  ApiClient._();

  static const _tokenKey = 'auth_token';

  static Dio? _instance;

  static Dio get instance {
    if (_instance != null) return _instance!;
    _instance = _create();
    return _instance!;
  }

  static String? _token;

  /// 401 统一处理钩子：由启动处（main 内）绑定为清空登录态并回登录页，
  /// 避免 token 过期后 UI 停在受保护页满屏报错、无法返回登录。
  static void Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;

  static void setToken(String? token) {
    _token = token;
    unawaited(_persistToken(token));
  }

  /// 从本地恢复已持久化的 token（应用冷启动时调用）
  static Future<void> restoreToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_tokenKey);
      if (saved != null && saved.isNotEmpty) {
        _token = saved;
      }
    } catch (e) {
      log('恢复 token 失败: $e', name: 'api_client');
    }
  }

  static Future<void> _persistToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null || token.isEmpty) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token);
      }
    } catch (e) {
      log('持久化 token 失败: $e', name: 'api_client');
    }
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
          // Token 过期/无效：清空本地 token 并触发统一登出（回登录页）
          _token = null;
          unawaited(_persistToken(null));
          final cb = onUnauthorized;
          if (cb != null && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              cb();
            } finally {
              _handlingUnauthorized = false;
            }
          }
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