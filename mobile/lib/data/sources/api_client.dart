import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// Dio 客户端 Provider
/// 当前阶段 useMock=true，Repository 不会真实调用此 client；
/// 接入后端时，在 Repository 中切换数据源即可。
final Provider<Dio> dioProvider = Provider<Dio>((ProviderRef<Dio> ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        // 实际接入后从 SharedPreferences 读取 token
        // final String? token = await _storage.read(key: AppConfig.kToken);
        // if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) {
        handler.next(e);
      },
    ),
  );

  return dio;
});
