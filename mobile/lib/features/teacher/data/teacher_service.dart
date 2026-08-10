import 'dart:developer';
import '../../../core/config/api_config.dart';
import 'teacher_api.dart';

/// 教师端业务逻辑层
class TeacherService {
  final TeacherApi _api;

  TeacherService({TeacherApi? api}) : _api = api ?? TeacherApi();

  bool get _isMock => ApiConfig.useMockAuth;

  /// 获取病例列表
  Future<Map<String, dynamic>?> getCaseList() async {
    if (_isMock) return null;
    final resp = await _api.getCaseList();
    if (!resp.isSuccess) {
      log('getCaseList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建病例
  Future<Map<String, dynamic>?> createCase(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createCase(data);
    if (!resp.isSuccess) {
      log('createCase failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取作业列表
  Future<Map<String, dynamic>?> getAssignmentList() async {
    if (_isMock) return null;
    final resp = await _api.getAssignmentList();
    if (!resp.isSuccess) {
      log('getAssignmentList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建作业
  Future<Map<String, dynamic>?> createAssignment(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createAssignment(data);
    if (!resp.isSuccess) {
      log('createAssignment failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取作业进度
  Future<Map<String, dynamic>?> getAssignmentProgress(int id) async {
    if (_isMock) return null;
    final resp = await _api.getAssignmentProgress(id);
    if (!resp.isSuccess) {
      log('getAssignmentProgress failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取班级列表
  Future<Map<String, dynamic>?> getClasses() async {
    if (_isMock) return null;
    final resp = await _api.getClasses();
    if (!resp.isSuccess) {
      log('getClasses failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 提交资质认证材料
  Future<bool> submitAudit(Map<String, dynamic> data) async {
    if (_isMock) return true;
    final resp = await _api.submitAudit(data);
    if (!resp.isSuccess) {
      log('submitAudit failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 获取批阅队列
  Future<Map<String, dynamic>?> getReviewList() async {
    if (_isMock) return null;
    final resp = await _api.getReviewList();
    if (!resp.isSuccess) {
      log('getReviewList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取批阅详情
  Future<Map<String, dynamic>?> getReviewDetail(int instanceId) async {
    if (_isMock) return null;
    final resp = await _api.getReviewDetail(instanceId);
    if (!resp.isSuccess) {
      log('getReviewDetail failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 覆盖 AI 批阅结果
  Future<Map<String, dynamic>?> overrideReview(
    int instanceId,
    Map<String, dynamic> data,
  ) async {
    if (_isMock) return null;
    final resp = await _api.overrideReview(instanceId, data);
    if (!resp.isSuccess) {
      log('overrideReview failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取学情看板概览
  Future<Map<String, dynamic>?> getDashboardOverview() async {
    if (_isMock) return null;
    final resp = await _api.getDashboardOverview();
    if (!resp.isSuccess) {
      log('getDashboardOverview failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  // ========= AI 辅助 =========

  /// AI 生成 SP 病例草稿
  Future<Map<String, dynamic>?> getCaseDraft(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.getCaseDraft(data);
    if (!resp.isSuccess) {
      log('getCaseDraft failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 班级学情洞察
  Future<Map<String, dynamic>?> getClassInsight() async {
    if (_isMock) return null;
    final resp = await _api.getClassInsight();
    if (!resp.isSuccess) {
      log('getClassInsight failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 复核辅助
  Future<Map<String, dynamic>?> getReviewAssist(int instanceId) async {
    if (_isMock) return null;
    final resp = await _api.getReviewAssist(instanceId);
    if (!resp.isSuccess) {
      log('getReviewAssist failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 推荐作业病例
  Future<Map<String, dynamic>?> getRecommendCases(int classId) async {
    if (_isMock) return null;
    final resp = await _api.getRecommendCases(classId);
    if (!resp.isSuccess) {
      log('getRecommendCases failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 病例质检
  Future<Map<String, dynamic>?> getQualityCheck(int caseId) async {
    if (_isMock) return null;
    final resp = await _api.getQualityCheck(caseId);
    if (!resp.isSuccess) {
      log('getQualityCheck failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 自动生成练习题
  Future<Map<String, dynamic>?> getPracticeQuestions(int caseId) async {
    if (_isMock) return null;
    final resp = await _api.getPracticeQuestions(caseId);
    if (!resp.isSuccess) {
      log('getPracticeQuestions failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  // ========= 教材管理 =========

  /// 上传电子书文件
  Future<Map<String, dynamic>?> uploadTextbookFile(String filePath) async {
    if (_isMock) return null;
    final resp = await _api.uploadTextbookFile(filePath);
    if (!resp.isSuccess) {
      log('uploadTextbookFile failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建/上架教材
  Future<Map<String, dynamic>?> createTextbook(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createTextbook(data);
    if (!resp.isSuccess) {
      log('createTextbook failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 我的教材列表
  Future<Map<String, dynamic>?> getMyTextbooks({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getMyTextbooks(pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) {
      log('getMyTextbooks failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 下架教材
  Future<bool> deleteTextbook(int id) async {
    if (_isMock) return true;
    final resp = await _api.deleteTextbook(id);
    if (!resp.isSuccess) {
      log('deleteTextbook failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }
}