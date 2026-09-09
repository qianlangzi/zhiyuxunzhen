import 'dart:developer';
import '../../../core/config/api_config.dart';
import 'teacher_api.dart';

/// 教师端业务逻辑层
class TeacherService {
  final TeacherApi _api;

  TeacherService({TeacherApi? api}) : _api = api ?? TeacherApi();

  bool get _isMock => ApiConfig.useMockAuth;

  // ==================== 病例多模态素材 ====================

  /// 上传病例素材（图片/PDF/音频/视频）
  Future<Map<String, dynamic>?> uploadCaseMedia(String filePath) async {
    if (_isMock) return null;
    final resp = await _api.uploadCaseMedia(filePath);
    if (!resp.isSuccess) {
      log('uploadCaseMedia failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 素材建议
  Future<Map<String, dynamic>?> caseMaterialAdvice(int caseId) async {
    if (_isMock) return null;
    final resp = await _api.caseMaterialAdvice(caseId);
    if (!resp.isSuccess) {
      log('caseMaterialAdvice failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  // ==================== 每日病历闭环 ====================

  /// 最近期次列表
  Future<List<dynamic>> getMrSchedules({int limit = 30}) async {
    if (_isMock) return const [];
    final resp = await _api.getMrSchedules(limit: limit);
    if (!resp.isSuccess) {
      log('getMrSchedules failed: ${resp.message}', name: 'teacher_service');
      return const [];
    }
    return resp.data ?? const [];
  }

  /// 批阅台：某期学生病历列表
  Future<List<dynamic>> getMrRecords({
    required int scheduleId,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    if (_isMock) return const [];
    final resp = await _api.getMrRecords(
        scheduleId: scheduleId, pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) {
      log('getMrRecords failed: ${resp.message}', name: 'teacher_service');
      return const [];
    }
    return resp.data ?? const [];
  }

  /// 复核改分
  Future<Map<String, dynamic>?> reviewMrRecord({
    required int recordId,
    double? score,
    String? comment,
  }) async {
    if (_isMock) return null;
    final resp = await _api.reviewMrRecord(recordId: recordId, score: score, comment: comment);
    if (!resp.isSuccess) {
      log('reviewMrRecord failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 班级缺陷统计
  Future<List<dynamic>> getMrDefectStats({int? scheduleId}) async {
    if (_isMock) return const [];
    final resp = await _api.getMrDefectStats(scheduleId: scheduleId);
    if (!resp.isSuccess) {
      log('getMrDefectStats failed: ${resp.message}', name: 'teacher_service');
      return const [];
    }
    return resp.data ?? const [];
  }

  /// 获取病例列表（status: 0草稿 1已发布，null 不过滤）
  Future<Map<String, dynamic>?> getCaseList({int? status}) async {
    if (_isMock) return null;
    final resp = await _api.getCaseList(status: status);
    if (!resp.isSuccess) {
      log('getCaseList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 全部病例列表（含所有教师的病例）
  Future<Map<String, dynamic>?> getCaseListAll() async {
    if (_isMock) return null;
    final resp = await _api.getCaseListAll();
    if (!resp.isSuccess) {
      log('getCaseListAll failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 病例公开预览（全部病例中查看他人病例）
  Future<Map<String, dynamic>?> getPublicCasePreview(int id) async {
    if (_isMock) return null;
    final resp = await _api.previewPublicCase(id);
    if (!resp.isSuccess) {
      log('previewPublicCase failed: ${resp.message}', name: 'teacher_service');
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

  /// 创建病例并返回新病例 ID（用于保存草稿后建立作业）
  Future<int?> createCaseId(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createCaseId(data);
    if (!resp.isSuccess) {
      log('createCaseId failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 更新病例
  Future<bool> updateCase(int id, Map<String, dynamic> data) async {
    if (_isMock) return true;
    final resp = await _api.updateCase(id, data);
    if (!resp.isSuccess) {
      log('updateCase failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 发布病例到病例中心（病例广场）：后端将病例置为"待管理员审核"，
  /// 直接投递，不涉及选择班级 / 向管理员申请班级授权。
  Future<bool> publishCaseToMarket(int id) async {
    if (_isMock) return true;
    final resp = await _api.publishCase(id);
    if (!resp.isSuccess) {
      log('publishCase failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 获取病例完整配置（含隐藏疾病、标准路径、评分要点，用于继续编辑回填）
  Future<Map<String, dynamic>?> getCasePreview(int id) async {
    if (_isMock) return null;
    final resp = await _api.previewCase(id);
    if (!resp.isSuccess) {
      log('previewCase failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 删除草稿病例（仅本人、仅草稿可删）
  Future<bool> deleteCase(int id) async {
    if (_isMock) return true;
    final resp = await _api.deleteCase(id);
    if (!resp.isSuccess) {
      log('deleteCase failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 获取作业列表（后端 R<List<TeacherAssignmentListVO>>）
  Future<List<dynamic>?> getAssignmentList() async {
    if (_isMock) return null;
    final resp = await _api.getAssignmentList();
    if (!resp.isSuccess) {
      log('getAssignmentList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 病历广场公开列表（支持关键字 + 科室/难度筛选 + 排序）
  Future<Map<String, dynamic>?> getMarketList({
    String? department,
    int? difficulty,
    String? keyword,
    String? sortBy,
    String? order,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getMarketList(
      department: department,
      difficulty: difficulty,
      keyword: keyword,
      sortBy: sortBy,
      order: order,
    );
    if (!resp.isSuccess) {
      log('getMarketList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 病例广场在售科室列表（动态去重）
  Future<List<String>> getMarketDepartments() async {
    if (_isMock) return const [];
    final resp = await _api.getMarketDepartments();
    if (!resp.isSuccess || resp.data == null) return const [];
    return resp.data!
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 引用公开病例到我的病例库，返回新病例 ID
  Future<int?> quoteCase(int id) async {
    if (_isMock) return null;
    final resp = await _api.quoteCase(id);
    if (!resp.isSuccess) {
      log('quoteCase failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建作业（为班级学生生成实例），返回新作业 ID
  Future<int?> createAssignment(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createAssignment(data);
    if (!resp.isSuccess) {
      log('createAssignment failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 修改作业设置（延期 / 补交 / 公布策略），成功返回 true
  Future<bool> updateAssignmentSettings(
      int id, Map<String, dynamic> data) async {
    if (_isMock) return false;
    final resp = await _api.updateAssignmentSettings(id, data);
    if (!resp.isSuccess) {
      log('updateAssignmentSettings failed: ${resp.message}',
          name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 获取作业进度
  Future<Map<String, dynamic>?> getAssignmentProgress(int id) async {
    if (_isMock) return null;
    final resp = await _api.getAssignmentProgress(id);
    if (!resp.isSuccess) {
      log('getAssignmentProgress failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取当前教师已获授权的班级（后盾 R<List<TeachingClassVO>>）
  Future<List<Map<String, dynamic>>> getClasses() async {
    if (_isMock) return [];
    final resp = await _api.getClasses();
    if (!resp.isSuccess) {
      log('getClasses failed: ${resp.message}', name: 'teacher_service');
      return [];
    }
    return (resp.data ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
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

  // ========= 班级管理（教师自建 / 重命名 / 解散 / 成员 / 邀请） =========

  /// 我的全部备课资料（跨教案平铺，作业创建时选资料附件用）
  Future<List<Map<String, dynamic>>> getMyMaterials() async {
    if (_isMock) return const [];
    final resp = await _api.getMyMaterials();
    if (!resp.isSuccess) {
      log('getMyMaterials failed: ${resp.message}', name: 'teacher_service');
      return const [];
    }
    return (resp.data ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// 我的班级列表（含 inviteCode/teacherId）
  Future<List<Map<String, dynamic>>> getMyClasses() async {
    if (_isMock) return [];
    final resp = await _api.getMyClasses();
    if (!resp.isSuccess) {
      log('getMyClasses failed: ${resp.message}', name: 'teacher_service');
      return [];
    }
    return (resp.data ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// 新建班级，返回新班级信息（失败返回 null）
  Future<Map<String, dynamic>?> createClass(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createClass(data);
    if (!resp.isSuccess) {
      log('createClass failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 重命名班级
  Future<bool> renameClass(int id, Map<String, dynamic> data) async {
    if (_isMock) return true;
    final resp = await _api.renameClass(id, data);
    if (!resp.isSuccess) {
      log('renameClass failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 解散班级
  Future<bool> dissolveClass(int id) async {
    if (_isMock) return true;
    final resp = await _api.dissolveClass(id);
    if (!resp.isSuccess) {
      log('dissolveClass failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 班级成员（学生）列表
  Future<List<Map<String, dynamic>>> getClassMembers(int id) async {
    if (_isMock) return [];
    final resp = await _api.getClassMembers(id);
    if (!resp.isSuccess) {
      log('getClassMembers failed: ${resp.message}', name: 'teacher_service');
      return [];
    }
    return (resp.data ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// 班级详情（含邀请码）
  Future<Map<String, dynamic>?> getClassDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getClassDetail(id);
    if (!resp.isSuccess) {
      log('getClassDetail failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 批量保存班级排序（按传入 id 顺序）
  Future<bool> sortClasses(List<int> classIds) async {
    if (_isMock) return true;
    final resp = await _api.sortClasses(classIds);
    if (!resp.isSuccess) {
      log('sortClasses failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 获取批阅队列（按班级/学生分组的原始数据）
  Future<List<Map<String, dynamic>>> getReviewQueue({int? classId}) async {
    if (_isMock) return [];
    final resp = await _api.getReviewQueue(classId: classId);
    if (!resp.isSuccess) {
      log('getReviewQueue failed: ${resp.message}', name: 'teacher_service');
      return [];
    }
    return (resp.data ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// 获取批阅详情
  Future<Map<String, dynamic>?> getReviewDetail(
    int instanceId, {
    int? itemProgressId,
  }) async {
    if (_isMock) return null;
    final resp =
        await _api.getReviewDetail(instanceId, itemProgressId: itemProgressId);
    if (!resp.isSuccess) {
      log('getReviewDetail failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 覆盖 AI 批阅结果
  Future<Map<String, dynamic>?> overrideReview(
    int instanceId,
    Map<String, dynamic> data, {
    int? itemProgressId,
  }) async {
    if (_isMock) return null;
    final resp = await _api.overrideReview(instanceId, data,
        itemProgressId: itemProgressId);
    if (!resp.isSuccess) {
      log('overrideReview failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 我的作业申诉列表（status 为空=全部）
  Future<List<Map<String, dynamic>>> getAppealList({int? status}) async {
    if (_isMock) return [];
    final resp = await _api.getAppealList(status: status);
    if (!resp.isSuccess) {
      log('getAppealList failed: ${resp.message}', name: 'teacher_service');
      return [];
    }
    return (resp.data ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  /// 处理申诉（1已处理/2已驳回，可改分）
  Future<bool> handleAppeal(
    int appealId, {
    required int status,
    required String reply,
    double? newScore,
  }) async {
    if (_isMock) return true;
    final resp = await _api.handleAppeal(appealId,
        status: status, reply: reply, newScore: newScore);
    return resp.isSuccess;
  }

  /// 查询主观题批阅任务上下文（题目/学生答案/关联ID）
  Future<Map<String, dynamic>?> getEssayTask(int itemProgressId) async {
    if (_isMock) return null;
    final resp = await _api.getEssayTask(itemProgressId);
    if (!resp.isSuccess) {
      log('getEssayTask failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 主观题（简答/论述）AI 批阅
  /// [data] 需含 question/scoringPoints/studentAnswer 及可选 instanceId/itemProgressId/questionId/studentId
  Future<Map<String, dynamic>?> essayReview(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.essayReview(data);
    if (!resp.isSuccess) {
      log('essayReview failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 获取学情看板概览（classId 非空时按班级维度汇总）
  Future<Map<String, dynamic>?> getDashboardOverview({int? classId}) async {
    if (_isMock) return null;
    final resp = await _api.getDashboardOverview(classId: classId);
    if (!resp.isSuccess) {
      log('getDashboardOverview failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  // ========= 智能备课 =========

  /// 备课包列表
  Future<List<dynamic>?> getLessons() async {
    if (_isMock) return null;
    final resp = await _api.getLessons();
    if (!resp.isSuccess) {
      log('getLessons failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 备课包详情
  Future<Map<String, dynamic>?> getLessonDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getLessonDetail(id);
    if (!resp.isSuccess) {
      log('getLessonDetail failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建备课包，返回新备课包 ID
  Future<int?> createLesson(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createLesson(data);
    if (!resp.isSuccess) {
      log('createLesson failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 生成教学设计
  Future<Map<String, dynamic>?> generateLessonDesign(int id) async {
    if (_isMock) return null;
    final resp = await _api.generateLessonDesign(id);
    if (!resp.isSuccess) {
      log('generateLessonDesign failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// AI 生成课件素材/PPT 提纲（基于已生成的教案设计）
  Future<Map<String, dynamic>?> generateLessonPpt(int id) async {
    if (_isMock) return null;
    final resp = await _api.generateLessonPpt(id);
    if (!resp.isSuccess) {
      log('generateLessonPpt failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 保存人工确认/编辑后的 PPT 课件提纲
  Future<bool> saveLessonPpt(int id, Map<String, dynamic> ppt) async {
    if (_isMock) return true;
    final resp = await _api.saveLessonPpt(id, ppt);
    if (!resp.isSuccess) {
      log('saveLessonPpt failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 更新备课包基本信息（标题/科室/年级/关联病例/教案 JSON 回写）
  Future<bool> updateLesson(int id, Map<String, dynamic> data) async {
    if (_isMock) return true;
    final resp = await _api.updateLesson(id, data);
    if (!resp.isSuccess) {
      log('updateLesson failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 向导式备课对话
  Future<Map<String, dynamic>?> guideLesson(int id, String userReply) async {
    if (_isMock) return null;
    final resp = await _api.guideLesson(id, userReply);
    if (!resp.isSuccess) {
      log('guideLesson failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 导出教案 Word，返回 {url, filename}
  Future<Map<String, dynamic>?> exportLesson(int id) async {
    if (_isMock) return null;
    final resp = await _api.exportLesson(id);
    if (!resp.isSuccess) {
      log('exportLesson failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 上传课件资料，返回资料 ID（失败返回 null）
  Future<int?> uploadMaterial({
    required int lessonId,
    required String filePath,
    String? title,
    String? materialType,
    String? knowledgeTags,
  }) async {
    if (_isMock) return null;
    final resp = await _api.uploadMaterial(
      lessonId: lessonId,
      filePath: filePath,
      title: title,
      materialType: materialType,
      knowledgeTags: knowledgeTags,
    );
    if (!resp.isSuccess) {
      log('uploadMaterial failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 发布备课
  Future<bool> publishLesson(int id, Map<String, dynamic> data) async {
    if (_isMock) return false;
    final resp = await _api.publishLesson(id, data);
    if (!resp.isSuccess) {
      log('publishLesson failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return resp.isSuccess;
  }

  /// 删除备课包
  Future<bool> deleteLesson(int id) async {
    if (_isMock) return true;
    final resp = await _api.deleteLesson(id);
    if (!resp.isSuccess) {
      log('deleteLesson failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 批量删除备课包（多选删除，含废案清理）
  Future<bool> batchDeleteLessons(List<int> ids) async {
    if (_isMock) return true;
    final resp = await _api.batchDeleteLessons(ids);
    if (!resp.isSuccess) {
      log('batchDeleteLessons failed: ${resp.message}',
          name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 智能合并多个教案为一个，返回新教案 ID
  Future<int?> mergeLessons(List<int> ids, String? title) async {
    if (_isMock) return null;
    final resp = await _api.mergeLessons(ids, title);
    if (!resp.isSuccess) {
      log('mergeLessons failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 保存教案拖动排序（lessonIds 按展示顺序传入）
  Future<bool> sortLessons(List<int> lessonIds) async {
    if (_isMock) return true;
    final resp = await _api.sortLessons(lessonIds);
    if (!resp.isSuccess) {
      log('sortLessons failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  // ========= 学情预警 + 站内信 =========

  /// 预警总览
  Future<Map<String, dynamic>?> getAlertOverview() async {
    if (_isMock) return null;
    final resp = await _api.getAlertOverview();
    if (!resp.isSuccess) {
      log('getAlertOverview failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 预警学生列表
  Future<List<dynamic>?> getAlertList({int? level}) async {
    if (_isMock) return null;
    final resp = await _api.getAlertList(level: level);
    if (!resp.isSuccess) {
      log('getAlertList failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 生成 AI 干预建议
  Future<Map<String, dynamic>?> generateIntervention(int studentId) async {
    if (_isMock) return null;
    final resp = await _api.generateIntervention(studentId);
    if (!resp.isSuccess) {
      log('generateIntervention failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 立即触发学情预警全量扫描
  Future<bool> scanAlert() async {
    if (_isMock) return false;
    final resp = await _api.scanAlert();
    if (!resp.isSuccess) {
      log('scanAlert failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 站内信未读数
  Future<int> getUnreadCount() async {
    if (_isMock) return 0;
    final resp = await _api.getUnreadCount();
    if (!resp.isSuccess) return 0;
    return (resp.data?['data'] as num?)?.toInt() ?? 0;
  }

  /// 站内信列表
  Future<List<dynamic>?> getNotifications() async {
    if (_isMock) return null;
    final resp = await _api.getNotifications();
    if (!resp.isSuccess) return null;
    return resp.data;
  }

  /// 标记已读
  Future<void> markNotificationRead(int id) async {
    if (_isMock) return;
    await _api.markNotificationRead(id);
  }

  // ========= AI 辅助 =========

  /// AI 生成 SP 病例草稿
  /// 返回 (data, message)：data 为生成的草稿（失败为 null），message 为后端/AI 真实提示。
  Future<({Map<String, dynamic>? data, String message})> getCaseDraft(
      Map<String, dynamic> data) async {
    if (_isMock) return (data: null, message: '当前为 mock 模式，AI 不可用');
    final resp = await _api.getCaseDraft(data);
    if (!resp.isSuccess) {
      log('getCaseDraft failed: ${resp.message}', name: 'teacher_service');
      return (data: null, message: resp.message);
    }
    return (data: resp.data, message: resp.message);
  }

  /// AI 班级学情洞察
  Future<Map<String, dynamic>?> getClassInsight({int? classId}) async {
    if (_isMock) return null;
    final resp = await _api.getClassInsight(classId: classId);
    if (!resp.isSuccess) {
      log('getClassInsight failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  // ========= 学情诊断报告 =========

  /// 生成并持久化学情诊断报告
  Future<({Map<String, dynamic>? data, String message})> generateDiagnosisReport(
      {int? classId}) async {
    if (_isMock) return (data: null, message: '当前为 mock 模式');
    final resp = await _api.generateDiagnosisReport(classId: classId);
    if (!resp.isSuccess) {
      log('generateDiagnosisReport failed: ${resp.message}',
          name: 'teacher_service');
      return (data: null, message: resp.message);
    }
    return (data: resp.data, message: resp.message);
  }

  /// 学情诊断报告列表
  Future<List<Map<String, dynamic>>?> getDiagnosisReports() async {
    if (_isMock) return [];
    final resp = await _api.getDiagnosisReports();
    if (!resp.isSuccess) {
      log('getDiagnosisReports failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return (resp.data ?? []).cast<Map<String, dynamic>>();
  }

  /// 学情诊断报告详情
  Future<Map<String, dynamic>?> getDiagnosisReportDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getDiagnosisReportDetail(id);
    if (!resp.isSuccess) {
      log('getDiagnosisReportDetail failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 删除学情诊断报告
  Future<void> deleteDiagnosisReport(int id) async {
    if (_isMock) return;
    await _api.deleteDiagnosisReport(id);
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

  /// 病例广场公开详情（患者画像 + 知识点等）
  Future<Map<String, dynamic>?> getMarketDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getMarketDetail(id);
    if (!resp.isSuccess) {
      log('getMarketDetail failed: ${resp.message}', name: 'teacher_service');
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
      log('uploadTextbookFile failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 创建/上架教材
  Future<Map<String, dynamic>?> createTextbook(
      Map<String, dynamic> data) async {
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
    final resp =
        await _api.getMyTextbooks(pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) {
      log('getMyTextbooks failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 教材库（平台全部已上架教材，含他人上传）
  Future<Map<String, dynamic>?> getTextbookLibrary({
    int pageNum = 1,
    int pageSize = 50,
    String? department,
    String? keyword,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getTextbookLibrary(
      pageNum: pageNum,
      pageSize: pageSize,
      department: department,
      keyword: keyword,
    );
    if (!resp.isSuccess) {
      log('getTextbookLibrary failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 教材库科室列表（动态筛选用）
  Future<List<String>> getTextbookLibraryDepartments() async {
    if (_isMock) return const [];
    final resp = await _api.getTextbookLibraryDepartments();
    if (!resp.isSuccess || resp.data == null) return const [];
    return resp.data!
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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

  // ========= 题目管理（我的基础题库） =========

  /// 新增题目并返回题目 ID
  Future<int?> createQuestion(Map<String, dynamic> data) async {
    if (_isMock) return null;
    final resp = await _api.createQuestion(data);
    if (!resp.isSuccess) {
      log('createQuestion failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 更新题目
  Future<bool> updateQuestion(int id, Map<String, dynamic> data) async {
    if (_isMock) return true;
    final resp = await _api.updateQuestion(id, data);
    if (!resp.isSuccess) {
      log('updateQuestion failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 提交审核
  Future<bool> submitQuestion(int id) async {
    if (_isMock) return true;
    final resp = await _api.submitQuestion(id);
    if (!resp.isSuccess) {
      log('submitQuestion failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 删除题目
  Future<bool> deleteQuestion(int id) async {
    if (_isMock) return true;
    final resp = await _api.deleteQuestion(id);
    if (!resp.isSuccess) {
      log('deleteQuestion failed: ${resp.message}', name: 'teacher_service');
      return false;
    }
    return true;
  }

  /// 我的题目列表（分页，data 为 {records, total}）
  Future<Map<String, dynamic>?> getMyQuestions({
    int pageNum = 1,
    int pageSize = 20,
    int? adminAuditStatus,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getMyQuestions(
      pageNum: pageNum,
      pageSize: pageSize,
      adminAuditStatus: adminAuditStatus,
    );
    if (!resp.isSuccess) {
      log('getMyQuestions failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 全部基础题库（含所有人的题目，支持筛选 + 搜索）
  Future<Map<String, dynamic>?> getAllQuestions({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? knowledgeTag,
    int? difficulty,
    String? questionType,
    String? keyword,
    String order = 'desc',
  }) async {
    if (_isMock) return null;
    final resp = await _api.getAllQuestions(
      pageNum: pageNum,
      pageSize: pageSize,
      department: department,
      knowledgeTag: knowledgeTag,
      difficulty: difficulty,
      questionType: questionType,
      keyword: keyword,
      order: order,
    );
    if (!resp.isSuccess) {
      log('getAllQuestions failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 题库科室列表（筛选用）
  Future<List<String>> getQuestionDepartments() async {
    if (_isMock) return const [];
    final resp = await _api.getQuestionDepartments();
    if (!resp.isSuccess || resp.data == null) return const [];
    return resp.data!
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 题库知识点列表（筛选用）
  Future<List<String>> getQuestionKnowledgeTags() async {
    if (_isMock) return const [];
    final resp = await _api.getQuestionKnowledgeTags();
    if (!resp.isSuccess || resp.data == null) return const [];
    return resp.data!
        .map((e) => e.toString().trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 题库公开详情（全部题库中查看他人题目）
  Future<Map<String, dynamic>?> getPublicQuestion(int id) async {
    if (_isMock) return null;
    final resp = await _api.getPublicQuestion(id);
    if (!resp.isSuccess) {
      log('getPublicQuestion failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 题目详情
  Future<Map<String, dynamic>?> getQuestionDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getQuestionDetail(id);
    if (!resp.isSuccess) {
      log('getQuestionDetail failed: ${resp.message}', name: 'teacher_service');
      return null;
    }
    return resp.data;
  }

  /// 题库公开详情（全部题库中查看他人题目）
  Future<Map<String, dynamic>?> getPublicQuestionDetail(int id) async {
    if (_isMock) return null;
    final resp = await _api.getPublicQuestion(id);
    if (!resp.isSuccess) {
      log('getPublicQuestionDetail failed: ${resp.message}',
          name: 'teacher_service');
      return null;
    }
    return resp.data;
  }
}
