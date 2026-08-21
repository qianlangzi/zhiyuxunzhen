import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// 教师端 API 客户端
class TeacherApi {
  final Dio _dio;

  TeacherApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  // ========= 病例管理 =========

  /// 获取病例列表
  Future<ApiResponse<Map<String, dynamic>>> getCaseList() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/cases');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建病例
  Future<ApiResponse<Map<String, dynamic>>> createCase(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/teacher/cases', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建病例，返回新病例 ID（后端 R<Long>）
  Future<ApiResponse<int?>> createCaseId(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/teacher/cases', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 更新病例
  Future<ApiResponse<Map<String, dynamic>>> updateCase(int id, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>('/api/v1/teacher/cases/$id', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 预览病例
  Future<ApiResponse<Map<String, dynamic>>> previewCase(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/cases/$id/preview');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 发布病例到广场
  Future<ApiResponse<void>> publishCase(int id) async {
    try {
      await _dio.post('/api/v1/teacher/cases/$id/publish-to-market');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 作业管理 =========

  /// 病历广场公开列表（分页）
  Future<ApiResponse<Map<String, dynamic>>> getMarketList({
    int pageNum = 1,
    int pageSize = 50,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/case-market/list',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取作业列表
  Future<ApiResponse<Map<String, dynamic>>> getAssignmentList() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/assignments');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取班级列表（后端 R<List<TeachingClassVO>>，data 为数组）
  Future<ApiResponse<List<dynamic>>> getClasses() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/assignments/classes');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 引用病例到我的病例库（后端复制为独立副本，返回新病例 ID）
  Future<ApiResponse<int?>> quoteCase(int id) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/case-market/$id/quote');
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建作业
  Future<ApiResponse<Map<String, dynamic>>> createAssignment(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/teacher/assignments', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取作业进度
  Future<ApiResponse<Map<String, dynamic>>> getAssignmentProgress(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/assignments/$id/progress');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 个人资质 =========

  /// 提交资质认证材料
  Future<ApiResponse<void>> submitAudit(Map<String, dynamic> data) async {
    try {
      await _dio.post('/api/v1/teacher/profile/audit-submit', data: data);
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 批阅复核 =========

  /// 获取我的批阅队列
  Future<ApiResponse<Map<String, dynamic>>> getReviewList() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/reviews');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取批阅详情
  Future<ApiResponse<Map<String, dynamic>>> getReviewDetail(int instanceId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/teacher/reviews/$instanceId');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教师人工覆盖 AI 批阅结果
  Future<ApiResponse<Map<String, dynamic>>> overrideReview(
    int instanceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/$instanceId/override',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 学情看板 =========

  /// 获取教师学情看板概览
  Future<ApiResponse<Map<String, dynamic>>> getDashboardOverview() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/dashboard/overview',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= AI 辅助 =========

  /// AI 生成 SP 病例草稿
  Future<ApiResponse<Map<String, dynamic>>> getCaseDraft(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/ai/case-draft',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 班级学情洞察
  Future<ApiResponse<Map<String, dynamic>>> getClassInsight() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/class-insight',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 复核辅助
  Future<ApiResponse<Map<String, dynamic>>> getReviewAssist(int instanceId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/review-assist/$instanceId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 推荐作业病例
  Future<ApiResponse<Map<String, dynamic>>> getRecommendCases(int classId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/recommend-cases',
        queryParameters: {'classId': classId},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 病例质检
  Future<ApiResponse<Map<String, dynamic>>> getQualityCheck(int caseId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/quality-check/$caseId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 自动生成练习题
  Future<ApiResponse<Map<String, dynamic>>> getPracticeQuestions(int caseId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/practice-questions/$caseId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 教材管理（教师上传电子书） =========

  /// 上传电子书文件，返回 {url, filename}
  Future<ApiResponse<Map<String, dynamic>>> uploadTextbookFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/textbooks/upload',
        data: formData,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建/上架教材
  Future<ApiResponse<Map<String, dynamic>>> createTextbook(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/teacher/textbooks', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的教材列表
  Future<ApiResponse<Map<String, dynamic>>> getMyTextbooks({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/textbooks',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 下架教材
  Future<ApiResponse<void>> deleteTextbook(int id) async {
    try {
      await _dio.delete('/api/v1/teacher/textbooks/$id');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  String _mapError(DioException e) {
    log('TeacherApi error: ${e.message}', name: 'teacher_api');
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