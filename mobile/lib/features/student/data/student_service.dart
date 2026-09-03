import 'dart:developer';
import 'dart:typed_data';
import 'package:dio/dio.dart';
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
    int? assignmentItemProgressId,
  }) async {
    if (_isMock) return null;
    final resp = await _api.startSession(
      caseId: caseId,
      assignmentInstanceId: assignmentInstanceId,
      assignmentItemProgressId: assignmentItemProgressId,
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

  Future<bool> retrySessionArchive(int sessionId) async {
    if (_isMock) return true;
    final resp = await _api.retrySessionArchive(sessionId);
    if (!resp.isSuccess) {
      log('retrySessionArchive failed: ${resp.message}', name: 'student_service');
    }
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

  /// 提交大病历（组合包场景可传 itemProgressId 定位任务项）
  Future<Map<String, dynamic>?> submitRecord({
    required int instanceId,
    required String medicalRecordText,
    int? itemProgressId,
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitRecord(
      instanceId: instanceId,
      medicalRecordText: medicalRecordText,
      itemProgressId: itemProgressId,
    );
    if (!resp.isSuccess) {
      log('submitRecord failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 提交练习任务项答案（客观题自动判分）
  Future<Map<String, dynamic>?> submitPractice({
    required int instanceId,
    required int itemProgressId,
    required Map<int, String> answers,
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitPractice(
      instanceId: instanceId,
      itemProgressId: itemProgressId,
      answers: answers,
    );
    if (!resp.isSuccess) {
      log('submitPractice failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 标记阅读任务项完成
  Future<Map<String, dynamic>?> completeReading({
    required int instanceId,
    required int itemProgressId,
  }) async {
    if (_isMock) return null;
    final resp = await _api.completeReading(
      instanceId: instanceId,
      itemProgressId: itemProgressId,
    );
    if (!resp.isSuccess) {
      log('completeReading failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 待办作业列表
  Future<Map<String, dynamic>?> getTodoAssignments({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getTodoAssignments(pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) {
      log('getTodoAssignments failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 作业实例详情
  Future<Map<String, dynamic>?> getAssignmentDetail(int instanceId) async {
    if (_isMock) return null;
    final resp = await _api.getAssignmentDetail(instanceId);
    if (!resp.isSuccess) {
      log('getAssignmentDetail failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取成长页概览
  Future<Map<String, dynamic>?> getReportOverview() async {
    if (_isMock) return null;
    final resp = await _api.getReportOverview();
    if (!resp.isSuccess) {
      log('getReportOverview failed: ${resp.message}', name: 'student_service');
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

  /// 单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并缓存）
  Future<Map<String, dynamic>?> analyzeMistake(int id) async {
    if (_isMock) return null;
    final resp = await _api.analyzeMistake(id);
    if (!resp.isSuccess) {
      log('analyzeMistake failed: ${resp.message}', name: 'student_service');
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

  /// OSCE 考核历史记录列表
  Future<List<dynamic>?> getOsceHistory() async {
    if (_isMock) return null;
    final resp = await _api.getOsceHistory();
    if (!resp.isSuccess) {
      log('getOsceHistory failed: ${resp.message}', name: 'student_service');
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

  /// 导师按需小结（进行中会话：思维树 + 苏格拉底提示，2026-09-03）
  Future<Map<String, dynamic>?> getSessionMentor(int sessionId) async {
    if (_isMock) return null;
    final resp = await _api.getSessionMentor(sessionId);
    if (!resp.isSuccess) {
      log('getSessionMentor failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 生成学习路径（服务端自动组装本人事实快照，返回结构化路径）
  Future<Map<String, dynamic>?> generateLearningPath() async {
    if (_isMock) return null;
    final resp = await _api.generateLearningPath();
    if (!resp.isSuccess) {
      log('generateLearningPath failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 生成个性化自测卷（P2-4 AI 组卷）
  Future<Map<String, dynamic>?> generatePaper({
    int count = 10,
    int? difficulty,
    List<String> focusTags = const [],
  }) async {
    if (_isMock) return null;
    final resp = await _api.generatePaper(
        count: count, difficulty: difficulty, focusTags: focusTags);
    if (!resp.isSuccess) {
      log('generatePaper failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 提交 AI 组卷任务（异步生成，返回任务信息）
  Future<Map<String, dynamic>?> submitPaperTask({
    int count = 10, int? difficulty, List<String> focusTags = const [],
    List<String> questionTypes = const [], List<String> departments = const [],
    List<String> knowledgeTags = const [],
  }) async {
    if (_isMock) return null;
    final resp = await _api.submitPaperTask(
      count: count,
      difficulty: difficulty,
      focusTags: focusTags,
      questionTypes: questionTypes,
      departments: departments,
      knowledgeTags: knowledgeTags,
    );
    if (!resp.isSuccess) { log('submitPaperTask failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 查询 AI 组卷任务结果
  Future<Map<String, dynamic>?> getPaperTask(String taskId) async {
    if (_isMock) return null;
    final resp = await _api.getPaperTask(taskId);
    if (!resp.isSuccess) { log('getPaperTask failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 提交体验反馈（P2-3）
  Future<bool> submitFeedback({
    String category = 'general',
    int rating = 0,
    String content = '',
  }) async {
    if (_isMock) return true;
    final resp = await _api.submitFeedback(
        category: category, rating: rating, content: content);
    return resp.isSuccess;
  }

  /// 我的反馈列表（P2-3）
  Future<Map<String, dynamic>?> myFeedback() async {
    if (_isMock) return null;
    final resp = await _api.myFeedback();
    if (!resp.isSuccess) {
      log('myFeedback failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 关键动作埋点（P2-3，失败静默）
  void track(String action, {String detail = ''}) {
    if (_isMock) return;
    _api.track(action, detail: detail);
  }

  /// 我的学习目标（P2-1）
  Future<Map<String, dynamic>?> myGoal() async {
    if (_isMock) return null;
    final resp = await _api.myGoal();
    if (!resp.isSuccess) {
      log('myGoal failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 设定/更新学习目标（P2-1）
  Future<bool> upsertGoal({
    String title = '',
    String targetMetric = '',
    String targetDate = '',
  }) async {
    if (_isMock) return true;
    final resp = await _api.upsertGoal(
        title: title, targetMetric: targetMetric, targetDate: targetDate);
    return resp.isSuccess;
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

  /// 流式问诊（SSE · ChatGPT 打字机效果）· 事件契约：
  /// message / tree / stage / socrates / safety / citation / status / error / done。
  Stream<AskStreamEvent> chatRoomStream({
    required int sessionId,
    required String message,
    int connectRetries = 2,
    CancelToken? cancelToken,
  }) {
    if (_isMock) {
      // Mock 模式返回恒空流，前端据此降级到同步路径
      return const Stream<AskStreamEvent>.empty();
    }
    return _api.chatRoomStream(
      sessionId: sessionId,
      message: message,
      connectRetries: connectRetries,
      cancelToken: cancelToken,
    );
  }

  /// 上传问诊影像（本地目录存储），返回 {url, filename}
  Future<Map<String, dynamic>?> uploadImage({
    required int sessionId,
    required String filePath,
  }) async {
    if (_isMock) return null;
    final resp = await _api.uploadImage(sessionId: sessionId, filePath: filePath);
    if (!resp.isSuccess) {
      log('uploadImage failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// AI 学伴对话（P1-2，学习陪伴）· 同步
  Future<Map<String, dynamic>?> companion({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    if (_isMock) return null;
    final resp = await _api.companion(message: message, history: history);
    if (!resp.isSuccess) {
      log('companion failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// AI 学伴对话（P1-2）· 流式（SSE），供 CompanionScreen 逐字渲染
  ///
  /// [cancelToken] 用于页面销毁时取消底层 HTTP 连接，避免 SSE 请求在页面
  /// pop 后仍挂到超时才释放（后端 SseEmitter 不超时，会长期占用线程）。
  Stream<AskStreamEvent> companionStream({
    required String message, List<Map<String, String>> history = const [],
    String? imageUrl, int? conversationId, int connectRetries = 2, CancelToken? cancelToken,
  }) {
    return _api.companionStream(
        message: message,
        history: history,
        imageUrl: imageUrl,
        conversationId: conversationId,
        connectRetries: connectRetries,
        cancelToken: cancelToken);
  }

  /// 学伴会话列表（分页）
  Future<Map<String, dynamic>?> getCompanionConversations({int pageNum = 1, int pageSize = 10}) async {
    if (_isMock) return null;
    final resp = await _api.getCompanionConversations(pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) { log('getCompanionConversations failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 新建学伴会话
  Future<Map<String, dynamic>?> createCompanionConversation({required String title}) async {
    if (_isMock) return null;
    final resp = await _api.createCompanionConversation(title: title);
    if (!resp.isSuccess) { log('createCompanionConversation failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 重命名学伴会话
  Future<Map<String, dynamic>?> renameCompanionConversation(int id, String title) async {
    if (_isMock) return null;
    final resp = await _api.renameCompanionConversation(id, title);
    if (!resp.isSuccess) { log('renameCompanionConversation failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 删除学伴会话
  Future<bool> deleteCompanionConversation(int id) async {
    if (_isMock) return true;
    final resp = await _api.deleteCompanionConversation(id);
    if (!resp.isSuccess) { log('deleteCompanionConversation failed: ${resp.message}', name: 'student_service'); }
    return resp.isSuccess;
  }

  /// 学伴会话消息分页列表
  Future<Map<String, dynamic>?> getCompanionMessages(int conversationId, {int pageNum = 1, int pageSize = 20}) async {
    if (_isMock) return null;
    final resp = await _api.getCompanionMessages(conversationId, pageNum: pageNum, pageSize: pageSize);
    if (!resp.isSuccess) { log('getCompanionMessages failed: ${resp.message}', name: 'student_service'); return null; }
    return resp.data;
  }

  /// 写入一条学伴会话消息（落库，供换设备 / 清缓存后恢复历史）
  ///
  /// 后端接口此前从未被调用，对话只存在于本地 SharedPreferences，
  /// 导致换设备或清缓存后历史全部丢失，后端 messages 表恒为空。
  Future<bool> addCompanionMessage(
    int conversationId, {
    required String role,
    required String content,
    String? imageUrl,
  }) async {
    if (_isMock) return false;
    final resp = await _api.createCompanionMessage(
      conversationId,
      sender: role,
      content: content,
      imageUrl: imageUrl,
    );
    if (!resp.isSuccess) {
      log('addCompanionMessage failed: ${resp.message}', name: 'student_service');
      return false;
    }
    return true;
  }

  /// 学习任务聚合列表（备课资料 + 病例作业）
  Future<List<dynamic>?> getStudentTasks() async {
    if (_isMock) return null;
    final resp = await _api.getStudentTasks();
    if (!resp.isSuccess) {
      log('getStudentTasks failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 影像 AI 读图分析，返回 {finding, safetyBlocked, ...}
  Future<Map<String, dynamic>?> analyzeImage({
    required int sessionId,
    required String imageUrl,
    List<double>? imageBbox,
    String? studentNote,
  }) async {
    if (_isMock) return null;
    final resp = await _api.analyzeImage(
      sessionId: sessionId,
      imageUrl: imageUrl,
      imageBbox: imageBbox,
      studentNote: studentNote,
    );
    if (!resp.isSuccess) {
      log('analyzeImage failed: ${resp.message}', name: 'student_service');
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

  /// 教材科室分类列表
  Future<List<dynamic>?> getTextbookDepartments() async {
    if (_isMock) return null;
    final resp = await _api.getTextbookDepartments();
    if (!resp.isSuccess) {
      log('getTextbookDepartments failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 基础题分页列表
  Future<Map<String, dynamic>?> getQuestions({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? knowledgeTag,
    int? difficulty,
    String? questionType,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getQuestions(
      pageNum: pageNum,
      pageSize: pageSize,
      department: department,
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

  /// 科室（模块）列表，用于刷题入口
  Future<List<dynamic>?> getQuestionDepartments() async {
    if (_isMock) return null;
    final resp = await _api.getQuestionDepartments();
    if (!resp.isSuccess) {
      log('getQuestionDepartments failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 知识点列表，用于题库筛选
  Future<List<dynamic>?> getQuestionKnowledgeTags() async {
    if (_isMock) return null;
    final resp = await _api.getQuestionKnowledgeTags();
    if (!resp.isSuccess) {
      log('getQuestionKnowledgeTags failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 按科室刷题（单页返回，逐题/翻页）
  Future<Map<String, dynamic>?> getQuestionsByDepartment({
    int pageNum = 1,
    int pageSize = 1,
    required String department,
    int? difficulty,
  }) async {
    if (_isMock) return null;
    final resp = await _api.getQuestionsByDepartment(
      pageNum: pageNum,
      pageSize: pageSize,
      department: department,
      difficulty: difficulty,
    );
    if (!resp.isSuccess) {
      log('getQuestionsByDepartment failed: ${resp.message}', name: 'student_service');
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

  /// 薄弱点学情诊断（统计 + AI 归因合并）
  Future<Map<String, dynamic>?> getAiDiagnosis() async {
    if (_isMock) return null;
    final resp = await _api.getAiDiagnosis();
    if (!resp.isSuccess) {
      log('getAiDiagnosis failed: ${resp.message}', name: 'student_service');
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

  /// 以图搜图（P1-4 多模态影像检索）
  Future<Map<String, dynamic>?> searchKnowledgeByImage({
    required String imageBase64,
    String? text,
    int topK = 5,
    String? subject,
  }) async {
    if (_isMock) return null;
    final resp = await _api.searchKnowledgeByImage(
      imageBase64: imageBase64,
      text: text,
      topK: topK,
      subject: subject,
    );
    if (!resp.isSuccess) {
      log('searchKnowledgeByImage failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 获取教材原图字节（P1-4 影像检索结果回显）
  Future<Uint8List?> getKnowledgeImageBytes(String imageKey) async {
    if (_isMock) return null;
    return _api.getKnowledgeImageBytes(imageKey);
  }

  /// 通过邀请码加入班级，返回 (data, message)
  Future<({Map<String, dynamic>? data, String message})> joinClass(
      String inviteCode) async {
    if (_isMock) return (data: null, message: '当前为 mock 模式，班级加入不可用');
    final resp = await _api.joinClass(inviteCode);
    if (!resp.isSuccess) {
      log('joinClass failed: ${resp.message}', name: 'student_service');
      return (data: null, message: resp.message);
    }
    // 后端 R.message 为 "ok"，此处返回成功提示
    return (data: resp.data, message: '加入成功');
  }
/// 发起批阅申诉（P2-1）
  Future<int?> createAppeal({
    required int instanceId,
    required String reason,
  }) async {
    if (_isMock) return null;
    final resp = await _api.createAppeal(instanceId: instanceId, reason: reason);
    if (!resp.isSuccess) {
      log('createAppeal failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 我的申诉列表（P2-1）
  Future<List<dynamic>?> myAppeals() async {
    if (_isMock) return null;
    final resp = await _api.myAppeals();
    if (!resp.isSuccess) {
      log('myAppeals failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }
/// 我的课程（已加入班级的多对多列表）
  Future<List<dynamic>?> getMyClasses() async {
    if (_isMock) return null;
    final resp = await _api.getMyClasses();
    if (!resp.isSuccess) {
      log('getMyClasses failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }

  /// 班级详情（教师分享的资料与作业，闭环）
  Future<Map<String, dynamic>?> getClassDetail(int classId) async {
    if (_isMock) return null;
    final resp = await _api.getClassDetail(classId);
    if (!resp.isSuccess) {
      log('getClassDetail failed: ${resp.message}', name: 'student_service');
      return null;
    }
    return resp.data;
  }
}

final studentServiceProvider = Provider<StudentService>((ref) {
  return StudentService();
});
