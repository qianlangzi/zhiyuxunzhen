import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import 'student_api.dart';

/// 学生端业务逻辑层
/// 支持 Mock 模式和真实 API 模式
class StudentService {
  final StudentApi _api;

  StudentService({StudentApi? api}) : _api = api ?? StudentApi();

  bool get _isMock => ApiConfig.useMockAuth;

  /// 获取今日每日一例
  Future<Map<String, dynamic>?> getTodayDailyCase() async {
    if (_isMock) return null; // UI 层使用硬编码数据
    final resp = await _api.getTodayDailyCase();
    if (!resp.isSuccess) {
      log('getTodayDailyCase failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 提交每日一例答案
  Future<Map<String, dynamic>?> submitDailyCase({
    required int scheduleId,
    required String answer,
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitDailyCase(scheduleId: scheduleId, answer: answer);
    if (!resp.isSuccess) {
      log('submitDailyCase failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 启动问诊会话
  Future<Map<String, dynamic>?> startSession({
    required int caseId,
    int? assignmentInstanceId,
  }) async {
    if (_isMock) return null;
    final resp = await _api.startSession(
      caseId: caseId,
      assignmentInstanceId: assignmentInstanceId,
    );
    if (!resp.isSuccess) {
      log('startSession failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取会话详情
  Future<Map<String, dynamic>?> getSessionDetail(int sessionId) async {
    if (_isMock) return null;
    final resp = await _api.getSessionDetail(sessionId);
    if (!resp.isSuccess) {
      log('getSessionDetail failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 结束会话
  Future<bool> finishSession(int sessionId) async {
    if (_isMock) return true;
    final resp = await _api.finishSession(sessionId);
    return resp.isSuccess;
  }

  /// 获取我的作业列表
  Future<Map<String, dynamic>?> getMyAssignments({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getMyAssignments(pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) {
      log('getMyAssignments failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 提交大病历
  Future<Map<String, dynamic>?> submitRecord({
    required int instanceId,
    required String medicalRecordText,
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitRecord(
      instanceId: instanceId,
      medicalRecordText: medicalRecordText,
    );
    if (!resp.isSuccess) {
      log('submitRecord failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取报告概览
  Future<Map<String, dynamic>?> getReportOverview() async {
    if (_isMock) return null;
    final resp = await _api.getReportOverview();
    if (!resp.isSuccess) {
      log('getReportOverview failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 导出报告
  Future<Map<String, dynamic>?> exportReport({
    List<int>? sessionIds,
    String? dateStart,
    String? dateEnd,
  }) async {
    if (_isMock) return null;
    final resp = await _api.exportReport(
      sessionIds: sessionIds,
      dateStart: dateStart,
      dateEnd: dateEnd,
    );
    if (!resp.isSuccess) {
      log('exportReport failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取错题本列表
  Future<Map<String, dynamic>?> getMistakes({
    int pageNum = 1,
    int pageSize = 10,
    String? mistakeType,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getMistakes(
      pageNum: pageNum,
      pageSize: pageSize,
      mistakeType: mistakeType,
    );
    if (!resp.isSuccess) {
      log('getMistakes failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取会话 OSCE 评估结果
  Future<Map<String, dynamic>?> getSessionEvaluation(int sessionId) async {
    if (_isMock) return null;
    final resp = await _api.getSessionEvaluation(sessionId);
    if (!resp.isSuccess) {
      log('getSessionEvaluation failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取会话思维树数据
  Future<Map<String, dynamic>?> getThinkingTree(int sessionId) async {
    if (_isMock) return null;
    final resp = await _api.getThinkingTree(sessionId);
    if (!resp.isSuccess) {
      log('getThinkingTree failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 生成学习路径
  Future<String?> generateLearningPath(int studentId) async {
    if (_isMock) return null;
    final resp = await _api.generateLearningPath(studentId);
    if (!resp.isSuccess) {
      log('generateLearningPath failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取薄弱知识点列表
  Future<List<dynamic>?> getWeaknesses() async {
    if (_isMock) return null;
    final resp = await _api.getWeaknesses();
    if (!resp.isSuccess) {
      log('getWeaknesses failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 发送问诊消息（同步返回 SP 回复等聚合数据）
  Future<Map<String, dynamic>?> sendMessage({
    required int sessionId,
    required String message,
  }) async {
    if (_isMock) return null;
    final resp = await _api.sendMessage(sessionId: sessionId, message: message);
    if (!resp.isSuccess) {
      log('sendMessage failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 教材分页列表
  Future<Map<String, dynamic>?> getTextbooks({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? keyword,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getTextbooks(
      pageNum: pageNum,
      pageSize: pageSize,
      department: department,
      keyword: keyword,
    );
    if (!resp.isSuccess) {
      log('getTextbooks failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 教材详情
  Future<Map<String, dynamic>?> getTextbookDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getTextbookDetail(id);
    if (!resp.isSuccess) {
      log('getTextbookDetail failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 基础题分页列表
  Future<Map<String, dynamic>?> getQuestions({
    int pageNum = 1,
    int pageSize = 20,
    String? knowledgeTag,
    int? difficulty,
    String? questionType,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getQuestions(
      pageNum: pageNum,
      pageSize: pageSize,
      knowledgeTag: knowledgeTag,
      difficulty: difficulty,
      questionType: questionType,
    );
    if (!resp.isSuccess) {
      log('getQuestions failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 提交基础题答案
  Future<Map<String, dynamic>?> submitQuestion({
    required int questionId,
    required String selectedAnswer,
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitQuestion(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
    );
    if (!resp.isSuccess) {
      log('submitQuestion failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 我的训练统计
  Future<Map<String, dynamic>?> getQuestionStats() async {
    if (_isMock) return null;
    final resp = await _api.getQuestionStats();
    if (!resp.isSuccess) {
      log('getQuestionStats failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 单个薄弱知识点推荐
  Future<Map<String, dynamic>?> getRecommendation(String knowledgeTag) async {
    if (_isMock) return null;
    final resp = await _api.getRecommendation(knowledgeTag);
    if (!resp.isSuccess) {
      log('getRecommendation failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 全部薄弱知识点推荐列表
  Future<List<dynamic>?> getRecommendations() async {
    if (_isMock) return null;
    final resp = await _api.getRecommendations();
    if (!resp.isSuccess) {
      log('getRecommendations failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 全局检索
  Future<Map<String, dynamic>?> searchResources(String keyword) async {
    if (_isMock) return null;
    final resp = await _api.searchResources(keyword);
    if (!resp.isSuccess) {
      log('searchResources failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }
}

final studentServiceProvider = Provider<StudentService>((ref) {
  return StudentService();
});