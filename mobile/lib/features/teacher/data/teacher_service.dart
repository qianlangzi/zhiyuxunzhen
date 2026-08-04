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
}