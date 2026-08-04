import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// 病例广场 API 客户端
class CaseMarketApi {
  final Dio _dio;

  CaseMarketApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  /// 获取病例广场列表（分页、筛选）
  Future<ApiResponse<Map<String, dynamic>>> getCaseList({
    int pageNum = 1,
    int pageSize = 10,
    String? department,
    int? difficulty,
    String? sortBy,
    String? order,
  }) async {
    try {
      final params = <String, dynamic>{
        'pageNum': pageNum,
        'pageSize': pageSize,
      };
      if (department != null) params['department'] = department;
      if (difficulty != null) params['difficulty'] = difficulty;
      if (sortBy != null) params['sortBy'] = sortBy;
      if (order != null) params['order'] = order;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/case-market/list',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取病例详情
  Future<ApiResponse<Map<String, dynamic>>> getCaseDetail(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/case-market/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 引用病例（复制为独立副本）
  Future<ApiResponse<Map<String, dynamic>>> quoteCase(int id) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/case-market/$id/quote');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  String _mapError(DioException e) {
    log('CaseMarketApi error: ${e.message}', name: 'case_market_api');
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '网络超时，请稍后重试',
      DioExceptionType.connectionError => '无法连接服务器，请检查网络',
      DioExceptionType.badResponse => '服务器异常：${e.response?.statusCode}',
      _ => e.message ?? '请求失败',
    };
  }
}