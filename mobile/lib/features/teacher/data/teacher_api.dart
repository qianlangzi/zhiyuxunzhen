import 'dart:developer';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// 教师端 API 客户端
class TeacherApi {
  final Dio _dio;

  TeacherApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  /// AI 类接口统一超时覆盖：全局 [ApiClient] receiveTimeout 仅 8 秒，而教师端
  /// AI 接口（学情洞察/复核辅助/推荐病例/质检/练习题）会同步调用 AI 中台 LLM，
  /// 实际耗时 10~30 秒甚至更久。不覆盖时会稳定抛 receiveTimeout，表现为
  /// 「点了没反应 / 提示 AI 暂不可用」，与 getCaseDraft 明确放宽 180s 保持同源一致。
  static final Options _aiOptions = Options(
    sendTimeout: const Duration(seconds: 180),
    receiveTimeout: const Duration(seconds: 180),
    connectTimeout: const Duration(seconds: 30),
  );

  // ========= 病例管理 =========

  /// 获取病例列表（status: 0草稿 1已发布，null 不过滤）
  Future<ApiResponse<Map<String, dynamic>>> getCaseList({
    int pageNum = 1,
    int pageSize = 20,
    int? status,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/cases',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (status != null) 'status': status,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 全部病例列表（含所有教师的病例）
  Future<ApiResponse<Map<String, dynamic>>> getCaseListAll({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/cases/all',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 病例公开预览（全部病例中查看他人病例）
  Future<ApiResponse<Map<String, dynamic>>> previewPublicCase(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/cases/public/$id/preview',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建病例
  Future<ApiResponse<Map<String, dynamic>>> createCase(
      Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/teacher/cases', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建病例，返回新病例 ID（后端 R<Long>）
  Future<ApiResponse<int?>> createCaseId(Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/teacher/cases', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 更新病例
  Future<ApiResponse<Map<String, dynamic>>> updateCase(
      int id, Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .put<Map<String, dynamic>>('/api/v1/teacher/cases/$id', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 预览病例
  Future<ApiResponse<Map<String, dynamic>>> previewCase(int id) async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/cases/$id/preview');
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

  /// 删除草稿病例（仅本人、仅草稿可删）
  Future<ApiResponse<void>> deleteCase(int id) async {
    try {
      await _dio.delete('/api/v1/teacher/cases/$id');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 作业管理 =========

  /// 病历广场公开列表（分页 + 关键字 + 科室/难度筛选 + 排序）
  Future<ApiResponse<Map<String, dynamic>>> getMarketList({
    int pageNum = 1,
    int pageSize = 50,
    String? department,
    int? difficulty,
    String? keyword,
    String? sortBy,
    String? order,
  }) async {
    try {
      final params = <String, dynamic>{
        'pageNum': pageNum,
        'pageSize': pageSize,
      };
      if (department != null && department.isNotEmpty) {
        params['department'] = department;
      }
      if (difficulty != null) params['difficulty'] = difficulty;
      if (keyword != null && keyword.trim().isNotEmpty) {
        params['keyword'] = keyword.trim();
      }
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

  /// 病例广场在售科室列表（动态去重，供筛选项渲染）
  Future<ApiResponse<List<dynamic>>> getMarketDepartments() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/case-market/departments',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的作业列表（后端 R<List<TeacherAssignmentListVO>>，data 为数组）
  Future<ApiResponse<List<dynamic>>> getAssignmentList() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/teacher/assignments');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取班级列表（后端 R<List<TeachingClassVO>>，data 为数组）
  Future<ApiResponse<List<dynamic>>> getClasses() async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/assignments/classes');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 引用病例到我的病例库（后端复制为独立副本，返回新病例 ID）
  Future<ApiResponse<int?>> quoteCase(int id) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/case-market/$id/quote');
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建作业（为班级学生生成实例），返回新作业 ID（后端 R<Long>）
  Future<ApiResponse<int?>> createAssignment(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/assignments',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 修改作业设置（延期 / 补交窗口 / 公布策略等）
  Future<ApiResponse<bool>> updateAssignmentSettings(
      int id, Map<String, dynamic> data) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/api/v1/teacher/assignments/$id/settings',
        data: data,
      );
      return ApiResponse(code: 0, message: 'ok', data: true);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取作业进度
  Future<ApiResponse<Map<String, dynamic>>> getAssignmentProgress(
      int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/teacher/assignments/$id/progress');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 班级管理（教师自建 / 重命名 / 解散 / 成员 / 邀请） =========

  /// 我的全部备课资料（跨教案平铺，作业创建时选资料附件用）
  Future<ApiResponse<List<dynamic>>> getMyMaterials() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/materials',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>? ?? const []);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的班级列表（data 为数组，含 inviteCode/teacherId）
  Future<ApiResponse<List<dynamic>>> getMyClasses() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/teacher/classes');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 新建班级，返回新班级信息（后端 R<TeachingClassVO>）
  Future<ApiResponse<Map<String, dynamic>>> createClass(
      Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/teacher/classes', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 重命名班级（仅创建教师）
  Future<ApiResponse<Map<String, dynamic>>> renameClass(
      int id, Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .put<Map<String, dynamic>>('/api/v1/teacher/classes/$id', data: data);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 解散班级（仅创建教师）
  Future<ApiResponse<void>> dissolveClass(int id) async {
    try {
      await _dio.delete('/api/v1/teacher/classes/$id');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 班级成员（学生）列表（data 为数组）
  Future<ApiResponse<List<dynamic>>> getClassMembers(int id) async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/classes/$id/members');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 班级详情（含邀请码）
  Future<ApiResponse<Map<String, dynamic>>> getClassDetail(int id) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/teacher/classes/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 批量保存班级排序（classIds 按展示顺序传入）
  Future<ApiResponse<void>> sortClasses(List<int> classIds) async {
    try {
      await _dio
          .post('/api/v1/teacher/classes/sort', data: {'classIds': classIds});
      return const ApiResponse(code: 0, message: 'ok');
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

  /// 获取我的批阅队列（后端 R<List<TeacherReviewQueueVO>>，data 为数组）
  /// [classId] 非空时按班过滤
  Future<ApiResponse<List<dynamic>>> getReviewQueue({int? classId}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/reviews',
        queryParameters: {if (classId != null) 'classId': classId},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取批阅详情
  Future<ApiResponse<Map<String, dynamic>>> getReviewDetail(
    int instanceId, {
    int? itemProgressId,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/$instanceId',
        queryParameters: {
          if (itemProgressId != null) 'itemProgressId': itemProgressId
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教师人工覆盖 AI 批阅结果
  Future<ApiResponse<Map<String, dynamic>>> overrideReview(
    int instanceId,
    Map<String, dynamic> data, {
    int? itemProgressId,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/$instanceId/override',
        data: data,
        queryParameters: {
          if (itemProgressId != null) 'itemProgressId': itemProgressId
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 查询主观题批阅任务上下文（题目/学生答案/关联ID），供教师批改页展示
  Future<ApiResponse<Map<String, dynamic>>> getEssayTask(
      int itemProgressId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/essay-task/$itemProgressId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 主观题（简答/论述）AI 批阅：按教师自定义评分要点批阅，返回维度评分与改进建议
  /// [data] 需含 question/scoringPoints/studentAnswer 及可选 instanceId/itemProgressId/questionId/studentId
  Future<ApiResponse<Map<String, dynamic>>> essayReview(
      Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/essay',
        data: data,
        // LLM 批阅耗时较长，放宽超时避免被误判为"网络超时"
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 批阅申诉 =========

  /// 我的作业申诉列表（status 为空=全部，否则按 0待处理/1已处理/2已驳回 过滤）
  Future<ApiResponse<List<dynamic>>> getAppealList({int? status}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/appeals',
        queryParameters: {if (status != null) 'status': status},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 处理申诉：status(1已处理/2已驳回) + reply，newScore 非空时改分覆盖
  Future<ApiResponse<bool>> handleAppeal(
    int appealId, {
    required int status,
    required String reply,
    double? newScore,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/reviews/appeals/$appealId/handle',
        data: {
          'status': status,
          'reply': reply,
          if (newScore != null) 'newScore': newScore,
        },
      );
      return const ApiResponse(code: 0, message: 'ok', data: true);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 学情看板 =========

  /// 获取教师学情看板概览（classId 非空时按班级维度汇总）
  Future<ApiResponse<Map<String, dynamic>>> getDashboardOverview(
      {int? classId}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/dashboard/overview',
        queryParameters: {if (classId != null) 'classId': classId},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= AI 辅助 =========

  /// AI 生成 SP 病例草稿
  ///
  /// 注意：LLM 生成耗时约 10~30 秒，远超全局 dio 默认 8 秒超时，
  /// 必须为本次调用单独放宽超时，否则必然触发 "网络超时"。
  Future<ApiResponse<Map<String, dynamic>>> getCaseDraft(
      Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/ai/case-draft',
        data: data,
        options: Options(
          // LLM 生成耗时不稳：首次冷启动可能达 60s+，必须给足读写超时，
          // 同时放宽建连超时避免模拟器/弱网首次 TCP 握手被误判为"网络超时"。
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 班级学情洞察
  Future<ApiResponse<Map<String, dynamic>>> getClassInsight({int? classId}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/class-insight',
        queryParameters: classId == null ? null : {'classId': classId},
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 复核辅助
  Future<ApiResponse<Map<String, dynamic>>> getReviewAssist(
      int instanceId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/review-assist/$instanceId',
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 推荐作业病例
  Future<ApiResponse<Map<String, dynamic>>> getRecommendCases(
      int classId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/recommend-cases',
        queryParameters: {'classId': classId},
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 病例广场公开详情（患者画像 + 知识点等，教师点击卡片查看）
  Future<ApiResponse<Map<String, dynamic>>> getMarketDetail(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/case-market/$id',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 引用病例到我的病例库（后端复制为独立副本，返回新病例 ID）

  // ========= 学情诊断报告 =========

  /// 生成并持久化学情诊断报告（classId 为空=全体学生）
  Future<ApiResponse<Map<String, dynamic>>> generateDiagnosisReport(
      {int? classId}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/ai/report/class',
        queryParameters: classId == null ? null : {'classId': classId},
        options: Options(
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 学情诊断报告列表
  Future<ApiResponse<List<dynamic>>> getDiagnosisReports() async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/ai/reports');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 学情诊断报告详情
  Future<ApiResponse<Map<String, dynamic>>> getDiagnosisReportDetail(
      int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/teacher/ai/reports/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 删除学情诊断报告
  Future<ApiResponse<void>> deleteDiagnosisReport(int id) async {
    try {
      await _dio.delete('/api/v1/teacher/ai/reports/$id');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 教材管理（教师上传电子书） =========

  /// 上传电子书文件，返回 {url, filename}
  Future<ApiResponse<Map<String, dynamic>>> uploadTextbookFile(
      String filePath) async {
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
  Future<ApiResponse<Map<String, dynamic>>> createTextbook(
      Map<String, dynamic> data) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/teacher/textbooks', data: data);
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

  /// 教材库（平台全部已上架教材，含他人上传，供教师浏览/引用）
  Future<ApiResponse<Map<String, dynamic>>> getTextbookLibrary({
    int pageNum = 1,
    int pageSize = 50,
    String? department,
    String? keyword,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/textbooks/library',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (department != null && department.isNotEmpty) 'department': department,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教材库科室列表（与学生端教材中心同源，供教材库动态筛选）
  Future<ApiResponse<List<dynamic>>> getTextbookLibraryDepartments() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/teacher/textbooks/library/departments');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
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

  // ========= 题目管理（我的基础题库） =========

  /// 新增题目，返回新题目 ID（后端 R<Long>）
  Future<ApiResponse<int?>> createQuestion(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/questions',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 更新题目
  Future<ApiResponse<Map<String, dynamic>>> updateQuestion(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/teacher/questions/$id',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交审核
  Future<ApiResponse<void>> submitQuestion(int id) async {
    try {
      await _dio.post('/api/v1/teacher/questions/$id/submit');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 删除题目
  Future<ApiResponse<void>> deleteQuestion(int id) async {
    try {
      await _dio.delete('/api/v1/teacher/questions/$id');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的题目列表（分页，data 为 {records, total}）
  Future<ApiResponse<Map<String, dynamic>>> getMyQuestions({
    int pageNum = 1,
    int pageSize = 20,
    int? adminAuditStatus,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/questions',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (adminAuditStatus != null) 'adminAuditStatus': adminAuditStatus,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 全部基础题库（含所有人的题目，支持科室/知识点/难度/题型筛选 + 关键字搜索 + 发布时间排序）
  Future<ApiResponse<Map<String, dynamic>>> getAllQuestions({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? knowledgeTag,
    int? difficulty,
    String? questionType,
    String? keyword,
    String order = 'desc',
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/questions/all',
        queryParameters: {
          'pageNum': pageNum,
          'pageSize': pageSize,
          if (department != null && department.isNotEmpty)
            'department': department,
          if (knowledgeTag != null && knowledgeTag.isNotEmpty)
            'knowledgeTag': knowledgeTag,
          if (difficulty != null) 'difficulty': difficulty,
          if (questionType != null && questionType.isNotEmpty)
            'questionType': questionType,
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          'order': order,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 题库科室列表（与学生端同源，供全部题库筛选项）
  Future<ApiResponse<List<dynamic>>> getQuestionDepartments() async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/questions/departments');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 题库知识点列表（与学生端同源，供全部题库筛选项）
  Future<ApiResponse<List<dynamic>>> getQuestionKnowledgeTags() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/teacher/questions/knowledge-tags');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 题库公开详情（全部题库中查看他人题目）
  Future<ApiResponse<Map<String, dynamic>>> getPublicQuestion(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/questions/public/$id',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 题目详情
  Future<ApiResponse<Map<String, dynamic>>> getQuestionDetail(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/questions/$id',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 智能备课 =========

  /// 备课包列表
  Future<ApiResponse<List<dynamic>>> getLessons() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/teacher/lessons');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 备课包详情（含资料/病例/教学设计）
  Future<ApiResponse<Map<String, dynamic>>> getLessonDetail(int id) async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/teacher/lessons/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 创建备课包，返回新备课包 ID（后端 R<Long>）
  Future<ApiResponse<int?>> createLesson(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 更新备课包基本信息（标题/科室/年级/关联病例/教案 JSON 回写）
  Future<ApiResponse<Map<String, dynamic>>> updateLesson(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 生成教学设计
  ///
  /// 注意：LLM 生成耗时约 10~60 秒（首次冷启动更长），超出全局 dio 默认 8 秒超时。
  /// 必须为本次调用单独放宽读写超时，否则必然触发 "网络超时" 并被上层误报为"生成失败"。
  Future<ApiResponse<Map<String, dynamic>>> generateLessonDesign(int id) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id/design',
        options: Options(
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 生成课件素材/PPT 提纲（基于已生成的教案设计）
  ///
  /// LLM 生成耗时约 10~60 秒，需放宽读写超时避免被误判为网络超时。
  Future<ApiResponse<Map<String, dynamic>>> generateLessonPpt(int id) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id/ppt',
        options: Options(
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 保存人工确认/编辑后的 PPT 课件提纲（返回是否成功）
  Future<ApiResponse<Map<String, dynamic>>> saveLessonPpt(
      int id, Map<String, dynamic> ppt) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id/ppt',
        data: ppt,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 向导式备课对话（回答本轮问题，AI 返回下一个问题或需求单）
  ///
  /// 每轮回答都要调一次 LLM 生成提问，同样需要放宽超时避免被误判为网络超时。
  Future<ApiResponse<Map<String, dynamic>>> guideLesson(
      int id, String userReply) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id/guide',
        data: {'userReply': userReply},
        options: Options(
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 导出教案 Word 文档，返回 {url, filename}
  Future<ApiResponse<Map<String, dynamic>>> exportLesson(int id) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/teacher/lessons/$id/export');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 上传课件资料
  ///
  /// 后端返回 R<Long>（资料 ID），需按 int 解析，否则 R<Long> 被约定按 Map 解析时
  /// 解析失败 do data 置空，导致后端已成功但前端永远显示"上传失败"。
  /// 课件多含视频/PDF 等大文件，须放宽读写超时。
  Future<ApiResponse<int?>> uploadMaterial({
    required int lessonId,
    required String filePath,
    String? title,
    String? materialType,
    String? knowledgeTags,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        if (title != null) 'title': title,
        if (materialType != null) 'materialType': materialType,
        if (knowledgeTags != null) 'knowledgeTags': knowledgeTags,
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$lessonId/materials',
        data: form,
        options: Options(
          sendTimeout: const Duration(seconds: 300),
          receiveTimeout: const Duration(seconds: 300),
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 发布备课
  Future<ApiResponse<Map<String, dynamic>>> publishLesson(
      int id, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/$id/publish',
        data: data,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 删除备课包
  Future<ApiResponse<Map<String, dynamic>>> deleteLesson(int id) async {
    try {
      final resp = await _dio
          .delete<Map<String, dynamic>>('/api/v1/teacher/lessons/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 批量删除备课包（多选删除，含废案清理），body {ids}
  Future<ApiResponse<Map<String, dynamic>>> batchDeleteLessons(
      List<int> ids) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/batch-delete',
        data: {'ids': ids},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 智能合并多个教案为一个，返回新教案 ID（body {ids, title}）
  Future<ApiResponse<int?>> mergeLessons(List<int> ids, String? title) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/lessons/merge',
        data: {'ids': ids, if (title != null) 'title': title},
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 批量保存教案排序（lessonIds 按展示顺序传入）
  Future<ApiResponse<void>> sortLessons(List<int> lessonIds) async {
    try {
      await _dio
          .post('/api/v1/teacher/lessons/sort', data: {'lessonIds': lessonIds});
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ========= 学情预警 + 站内信 =========

  /// 预警总览
  Future<ApiResponse<Map<String, dynamic>>> getAlertOverview() async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/teacher/alert/overview');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 预警学生列表
  Future<ApiResponse<List<dynamic>>> getAlertList({int? level}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/alert/list',
        queryParameters: {if (level != null) 'level': level},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 生成 AI 干预建议
  Future<ApiResponse<Map<String, dynamic>>> generateIntervention(
      int studentId) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/alert/$studentId/intervene',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 立即触发学情预警全量扫描
  Future<ApiResponse<void>> scanAlert() async {
    try {
      await _dio.post('/api/v1/teacher/alert/scan');
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 站内信未读数
  Future<ApiResponse<Map<String, dynamic>>> getUnreadCount() async {
    try {
      final resp = await _dio
          .get<Map<String, dynamic>>('/api/v1/notifications/unread-count');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 站内信列表
  Future<ApiResponse<List<dynamic>>> getNotifications() async {
    try {
      final resp =
          await _dio.get<Map<String, dynamic>>('/api/v1/notifications');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 标记站内信已读
  Future<ApiResponse<Map<String, dynamic>>> markNotificationRead(int id) async {
    try {
      final resp = await _dio
          .post<Map<String, dynamic>>('/api/v1/notifications/$id/read');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
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

  // ==================== 病例多模态素材 ====================

  /// 上传病例素材（图片/PDF/音频/视频，≤20MB），返回 url + mediaType
  Future<ApiResponse<Map<String, dynamic>>> uploadCaseMedia(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/teacher/cases/media',
        data: form,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 素材建议（该病例应准备的多模态材料清单）
  Future<ApiResponse<Map<String, dynamic>>> caseMaterialAdvice(int caseId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/ai/material-advice/$caseId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  // ==================== 每日病历闭环 ====================

  /// 最近期次列表
  Future<ApiResponse<List<dynamic>>> getMrSchedules({int limit = 30}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/daily-cases/mr/schedules',
        queryParameters: {'limit': limit},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>? ?? const []);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 批阅台：某期学生病历列表
  Future<ApiResponse<List<dynamic>>> getMrRecords({
    required int scheduleId,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/daily-cases/mr/records',
        queryParameters: {
          'scheduleId': scheduleId,
          'pageNum': pageNum,
          'pageSize': pageSize,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d['list'] as List<dynamic>? ?? const []);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 复核改分
  Future<ApiResponse<Map<String, dynamic>>> reviewMrRecord({
    required int recordId,
    double? score,
    String? comment,
  }) async {
    try {
      final resp = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/teacher/daily-cases/mr/records/$recordId/review',
        queryParameters: {
          if (score != null) 'score': score,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 班级缺陷统计（scheduleId 可空=全部期次）
  Future<ApiResponse<List<dynamic>>> getMrDefectStats({int? scheduleId}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/teacher/daily-cases/mr/defect-stats',
        queryParameters: {if (scheduleId != null) 'scheduleId': scheduleId},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>? ?? const []);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }
}
