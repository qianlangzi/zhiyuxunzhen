import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// 学生端 API 客户端
class StudentApi {
  final Dio _dio;

  StudentApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  /// 获取今日每日一例
  Future<ApiResponse<Map<String, dynamic>>> getTodayDailyCase() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/daily-cases/today');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交每日一例答案
  Future<ApiResponse<Map<String, dynamic>>> submitDailyCase({
    required int scheduleId,
    required String answer,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/daily-cases/submit',
        data: {'scheduleId': scheduleId, 'answer': answer},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 启动问诊会话
  Future<ApiResponse<Map<String, dynamic>>> startSession({
    required int caseId,
    int? assignmentInstanceId,
  }) async {
    try {
      final body = <String, dynamic>{'caseId': caseId};
      if (assignmentInstanceId != null) body['assignmentInstanceId'] = assignmentInstanceId;
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/sessions',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取会话详情
  Future<ApiResponse<Map<String, dynamic>>> getSessionDetail(int sessionId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/sessions/$sessionId');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 结束问诊会话
  Future<ApiResponse<void>> finishSession(int sessionId) async {
    try {
      await _dio.post('/api/v1/student/sessions/$sessionId/finish');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取我的作业列表
  Future<ApiResponse<Map<String, dynamic>>> getMyAssignments({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/assignments/my',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交大病历
  Future<ApiResponse<Map<String, dynamic>>> submitRecord({
    required int instanceId,
    required String medicalRecordText,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/assignments/$instanceId/submit-record',
        data: {'medicalRecordText': medicalRecordText},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取复盘报告概览
  Future<ApiResponse<Map<String, dynamic>>> getReportOverview() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/review-report/overview');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 导出复盘报告
  Future<ApiResponse<Map<String, dynamic>>> exportReport({
    List<int>? sessionIds,
    String? dateStart,
    String? dateEnd,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (sessionIds != null) body['sessionIds'] = sessionIds;
      if (dateStart != null) body['dateStart'] = dateStart;
      if (dateEnd != null) body['dateEnd'] = dateEnd;
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/review-report/export',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取错题本列表（分页，支持类型筛选）
  Future<ApiResponse<Map<String, dynamic>>> getMistakes({
    int pageNum = 1,
    int pageSize = 10,
    String? mistakeType,
  }) async {
    try {
      final params = <String, dynamic>{'pageNum': pageNum, 'pageSize': pageSize};
      if (mistakeType != null) params['mistakeType'] = mistakeType;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/mistakes',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取会话 OSCE 评估结果
  Future<ApiResponse<Map<String, dynamic>>> getSessionEvaluation(int sessionId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/evaluations/$sessionId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取会话思维树数据
  Future<ApiResponse<Map<String, dynamic>>> getThinkingTree(int sessionId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/evaluations/$sessionId/thinking-tree',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 生成学习路径
  Future<ApiResponse<String>> generateLearningPath(int studentId) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/learning-path/generate',
        data: {'studentId': studentId},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d.toString());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取我的薄弱知识点列表
  Future<ApiResponse<List<dynamic>>> getWeaknesses() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/weaknesses');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 发送问诊消息（同步返回 SP 回复）
  Future<ApiResponse<Map<String, dynamic>>> sendMessage({
    required int sessionId,
    required String message,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/sessions/$sessionId/chat',
        data: {'message': message},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  String _mapError(DioException e) {
    log('StudentApi error: ${e.message}', name: 'student_api');
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