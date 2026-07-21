import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final TokenStore tokenStore = ref.watch(tokenStoreProvider);
  late final Dio dio;
  dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(_SessionInterceptor(dio, tokenStore));
  return dio;
});

class _SessionInterceptor extends QueuedInterceptor {
  _SessionInterceptor(this._dio, this._tokenStore);

  final Dio _dio;
  final TokenStore _tokenStore;
  Future<bool>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token = await _tokenStore.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final int? code = _businessCode(response.data);
    if ((code == 1001 || code == 1002) &&
        !_isAuthenticationRequest(response.requestOptions.path) &&
        response.requestOptions.extra['retriedAfterRefresh'] != true) {
      final bool refreshed = await _refreshOnce();
      if (refreshed) {
        try {
          final RequestOptions original = response.requestOptions;
          original.extra['retriedAfterRefresh'] = true;
          original.headers.remove(HttpHeaders.authorizationHeader);
          final Response<dynamic> retried = await _dio.fetch<dynamic>(original);
          handler.resolve(retried);
          return;
        } on DioException catch (error) {
          handler.reject(error);
          return;
        }
      }
    }
    handler.next(response);
  }

  Future<bool> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    final String? refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final Dio refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final Response<dynamic> response = await refreshDio.post<dynamic>(
        '/api/v1/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      final String access = requireString(data, 'token');
      final String refresh = requireString(data, 'refreshToken');
      await _tokenStore.writeTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      return true;
    } catch (_) {
      await _tokenStore.clear();
      return false;
    }
  }

  int? _businessCode(dynamic body) {
    if (body is Map) return body['code'] as int?;
    return null;
  }

  bool _isAuthenticationRequest(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/sms-code');
  }
}

Map<String, dynamic> unwrapEnvelope(dynamic body) {
  if (body is! Map) {
    throw const ApiException(
      message: '服务端返回格式异常',
      kind: ApiErrorKind.contract,
    );
  }
  final int code = body['code'] is int ? body['code'] as int : -1;
  final String message = body['message']?.toString() ?? '请求失败';
  if (code != 0) {
    throw ApiException(
      code: code,
      message: message,
      kind: code == 1001 || code == 1002
          ? ApiErrorKind.unauthenticated
          : code == 1003
              ? ApiErrorKind.forbidden
              : ApiErrorKind.business,
    );
  }
  final dynamic data = body['data'];
  if (data is! Map) {
    throw const ApiException(
      message: '服务端缺少有效数据',
      kind: ApiErrorKind.contract,
    );
  }
  return Map<String, dynamic>.from(data);
}

Map<String, dynamic>? unwrapNullableEnvelope(dynamic body) {
  if (body is! Map) {
    throw const ApiException(
      message: '服务端返回格式异常',
      kind: ApiErrorKind.contract,
    );
  }
  final int code = body['code'] is int ? body['code'] as int : -1;
  if (code != 0) {
    throw ApiException(
      code: code,
      message: body['message']?.toString() ?? '请求失败',
      kind: code == 1001 || code == 1002
          ? ApiErrorKind.unauthenticated
          : ApiErrorKind.business,
    );
  }
  final dynamic data = body['data'];
  return data is Map ? Map<String, dynamic>.from(data) : null;
}

String requireString(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw ApiException(
    message: '服务端字段 $key 缺失',
    kind: ApiErrorKind.contract,
  );
}

ApiException mapDioException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(
        message: '连接超时，请检查网络后重试',
        kind: ApiErrorKind.timeout,
        cause: error,
      );
    }
    final dynamic body = error.response?.data;
    if (body is Map && body['message'] != null) {
      return ApiException(
        code: body['code'] is int ? body['code'] as int : -1,
        message: body['message'].toString(),
        kind: ApiErrorKind.business,
        cause: error,
      );
    }
    return ApiException(
      message: '无法连接服务器，请确认 Docker 后端已启动',
      kind: ApiErrorKind.network,
      cause: error,
    );
  }
  return ApiException(message: '请求失败：$error', cause: error);
}
