import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// 药品库 API 客户端
///
/// 只读接口（与病例广场一致）：列表（药理分类 / 科室 / 关键字搜索 / 分页）、
/// 筛选项动态下发、药品详情。无写入能力，教学参考展示用途。
class DrugApi {
  final Dio _dio;

  DrugApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  /// 药品列表（分页、分类 / 科室多选筛选、关键字搜索）
  ///
  /// [categories] 药理分类多选（服务端 IN 等值）；[departments] 科室多选
  /// （服务端多条件 OR LIKE，兼容「心血管」命中「心血管内科」）；
  /// [keyword] 服务端模糊匹配 通用名 / 商品名 / 适应症。
  Future<ApiResponse<Map<String, dynamic>>> getDrugList({
    int pageNum = 1,
    int pageSize = 10,
    List<String>? categories,
    List<String>? departments,
    String? keyword,
  }) async {
    try {
      final params = <String, dynamic>{
        'pageNum': pageNum,
        'pageSize': pageSize,
      };
      // Dio 对 List 值会编码成重复参数：category=a&category=b
      if (categories != null && categories.isNotEmpty) {
        params['category'] = categories;
      }
      if (departments != null && departments.isNotEmpty) {
        params['department'] = departments;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        params['keyword'] = keyword.trim();
      }
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/drugs/list',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取筛选项：药理分类 + 科室（动态去重）
  ///
  /// 药理分类由种子数据固定（相对稳定），科室为逗号分隔多值拆分去重；
  /// 前端筛选 chips 一律由此接口下发渲染，避免硬编码后新增条目筛不到。
  Future<ApiResponse<Map<String, dynamic>>> getFilters() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/drugs/filters');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 药品详情（说明书式教学摘要）
  Future<ApiResponse<Map<String, dynamic>>> getDrugDetail(int id) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/drugs/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  String _mapError(DioException e) {
    log('DrugApi error: ${e.message}', name: 'drug_api');
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
