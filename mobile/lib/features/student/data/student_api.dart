import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';

/// AI 学伴流式事件（SSE）。event ∈ {message, status, safety, error, done}
class AskStreamEvent {
  final String event;
  final Map<String, dynamic> data;
  const AskStreamEvent(this.event, this.data);
}

/// 学生端 API 客户端
class StudentApi {
  final Dio _dio;

  StudentApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  /// AI 类接口超时覆盖
  ///
  /// [ApiClient] 全局 receiveTimeout 仅 8 秒，而后端这批接口内部会同步调用
  /// AI 中台（LLM 全量生成 / OSCE 评分 / 多模态读图 / 向量检索），实际耗时
  /// 通常 20~90 秒。不覆盖时会稳定抛 receiveTimeout，表现为「点了没反应 /
  /// 提示失败」，看起来像链路没接上，实为超时。
  static final Options _aiOptions = Options(
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 30),
  );

  /// 大文件（影像）上传超时覆盖：弱网下 sendTimeout 需放宽
  static final Options _uploadOptions = Options(
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 120),
  );

  /// 中等耗时接口（判题 / 组卷任务提交 / 大 JSON 查询）
  static final Options _mediumOptions = Options(
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
  );

  // ==================== 每日病历（每日一例升级版） ====================

  /// 今日病历卡（排期 + 我的记录 + 连续打卡）
  Future<ApiResponse<Map<String, dynamic>>> getTodayDailyMr() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/student/daily-cases/mr/today');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 病历题库（往期列表）
  Future<ApiResponse<List<dynamic>>> getDailyMrBank({
    int pageNum = 1,
    int pageSize = 20,
    int? done,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/student/daily-cases/mr/bank',
          queryParameters: {
            'pageNum': pageNum,
            'pageSize': pageSize,
            if (done != null) 'done': done,
          });
      return ApiResponse.fromJson(resp.data!, (d) => d['list'] as List<dynamic>? ?? const []);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 题目详情（病例材料 + 九段定义 + 我的提交记录）
  Future<ApiResponse<Map<String, dynamic>>> getDailyMrDetail(int scheduleId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/student/daily-cases/mr/$scheduleId');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 段落教练（AI 三级提示）
  Future<ApiResponse<Map<String, dynamic>>> dailyMrHint({
    required int scheduleId,
    required String segmentKey,
    int hintLevel = 1,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/daily-cases/mr/hint',
        data: {
          'scheduleId': scheduleId,
          'segmentKey': segmentKey,
          'hintLevel': hintLevel,
        },
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交病历（九段内容 → AI 结构化批阅）
  Future<ApiResponse<Map<String, dynamic>>> submitDailyMr({
    required int scheduleId,
    required Map<String, String> segments,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/daily-cases/mr/submit',
        data: {'scheduleId': scheduleId, 'segments': segments},
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 打卡日历
  Future<ApiResponse<Map<String, dynamic>>> dailyMrCalendar({int? year}) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
          '/api/v1/student/daily-cases/mr/calendar',
          queryParameters: {if (year != null) 'year': year});
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 启动问诊会话
  Future<ApiResponse<Map<String, dynamic>>> startSession({
    required int caseId,
    int? assignmentInstanceId,
    int? assignmentItemProgressId,
  }) async {
    try {
      final body = <String, dynamic>{'caseId': caseId};
      if (assignmentInstanceId != null) body['assignmentInstanceId'] = assignmentInstanceId;
      if (assignmentItemProgressId != null) body['assignmentItemProgressId'] = assignmentItemProgressId;
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
      await _dio.post('/api/v1/student/sessions/$sessionId/finish', options: _aiOptions);
      return const ApiResponse(code: 0, message: 'ok');
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  Future<ApiResponse<void>> retrySessionArchive(int sessionId) async {
    try {
      final response = await _dio.post('/api/v1/student/sessions/$sessionId/archive/retry', options: _aiOptions);
      return ApiResponse<void>.fromJson(response.data, (_) => null);
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

  /// 提交大病历（组合包场景可传 itemProgressId 定位任务项）
  Future<ApiResponse<Map<String, dynamic>>> submitRecord({
    required int instanceId,
    required String medicalRecordText,
    int? itemProgressId,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/assignments/$instanceId/submit-record',
        queryParameters: {if (itemProgressId != null) 'itemProgressId': itemProgressId},
        data: {'medicalRecordText': medicalRecordText},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交练习任务项答案（客观题自动判分）
  Future<ApiResponse<Map<String, dynamic>>> submitPractice({
    required int instanceId,
    required int itemProgressId,
    required Map<int, String> answers,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/assignments/$instanceId/items/$itemProgressId/submit-practice',
        data: {'answers': answers},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 标记阅读任务项完成
  Future<ApiResponse<Map<String, dynamic>>> completeReading({
    required int instanceId,
    required int itemProgressId,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/assignments/$instanceId/items/$itemProgressId/complete-reading',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 待办作业列表（仅未完成：未开始/问诊中/格式打回）
  Future<ApiResponse<Map<String, dynamic>>> getTodoAssignments({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/assignments/todo',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 作业实例详情（查看作业 + 提交大病历）
  Future<ApiResponse<Map<String, dynamic>>> getAssignmentDetail(int instanceId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/assignments/$instanceId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取成长页概览（能力评分 + 近 90 天活动热力图）
  Future<ApiResponse<Map<String, dynamic>>> getReportOverview() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/review-report/overview');
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

  /// 单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并缓存）
  Future<ApiResponse<Map<String, dynamic>>> analyzeMistake(int id) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/mistakes/$id/analyze',
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 练同类题：以该错题的知识点 + AI 归因标签为焦点生成巩固练习
  Future<ApiResponse<Map<String, dynamic>>> drillMistake(int id,
      {int count = 5}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/mistakes/$id/drill',
        queryParameters: {'count': count},
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 回写错题复习状态（0未复习 1已复习 2已掌握）· 闭环出口，持久化到服务端
  Future<ApiResponse<Map<String, dynamic>>> markMistakeStatus(int id, int status) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/mistakes/$id/status',
        queryParameters: {'status': status},
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

  /// OSCE 考核历史记录列表（已完成会话）
  Future<ApiResponse<List<dynamic>>> getOsceHistory() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/evaluations/history');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
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

  /// 导师按需小结（进行中会话的思维树 + 苏格拉底提示，2026-09-03）
  ///
  /// 训练态不在对话流实时推送（防剧透），学生左滑主动唤出时按需生成。
  Future<ApiResponse<Map<String, dynamic>>> getSessionMentor(int sessionId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/sessions/$sessionId/mentor',
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 生成学习路径（为当前登录学生，服务端自动组装事实快照）
  /// [refresh] 为 false 时后端优先返回 24h 内缓存（秒开），
  /// true 时强制重新调 AI 生成（用户显式点「重新生成路径」才用）。
  Future<ApiResponse<Map<String, dynamic>>> generateLearningPath(
      {bool refresh = false}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/learning-path/generate',
        queryParameters: refresh ? {'refresh': true} : null,
        options: _aiOptions,
      );
      return ApiResponse.fromJson(
          resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 生成个性化自测卷（P2-4 AI 组卷：薄弱点优先 + 难度偏好）
  Future<ApiResponse<Map<String, dynamic>>> generatePaper({
    int count = 10,
    int? difficulty,
    List<String> focusTags = const [],
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/paper/generate',
        data: {
          'count': count,
          if (difficulty != null) 'difficulty': difficulty,
          'focusTags': focusTags,
        },
        options: _aiOptions,
      );
      return ApiResponse.fromJson(
          resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交体验反馈（P2-3 真实用户数据）
  Future<ApiResponse<int>> submitFeedback({
    String category = 'general',
    int rating = 0,
    String content = '',
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/feedback',
        data: {'category': category, 'rating': rating, 'content': content},
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的反馈列表（P2-3）
  Future<ApiResponse<Map<String, dynamic>>> myFeedback({
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/feedback',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 关键动作埋点（P2-3，失败静默不影响主流程）
  Future<void> track(String action, {String detail = ''}) async {
    try {
      await _dio.post('/api/v1/student/track',
          data: {'action': action, 'detail': detail});
    } on DioException catch (e) {
      log('track failed: ${e.message}', name: 'student_api');
    }
  }

  /// 我的学习目标（P2-1）
  Future<ApiResponse<Map<String, dynamic>>> myGoal() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/archive/goal');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 设定/更新学习目标（P2-1）
  Future<ApiResponse<int>> upsertGoal({
    String title = '',
    String targetMetric = '',
    String targetDate = '',
  }) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/student/archive/goal',
        data: {
          'title': title,
          'targetMetric': targetMetric,
          'targetDate': targetDate,
        },
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
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
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 发送问诊消息（流式 SSE · ChatGPT 打字机效果）· 事件契约：
  /// message / tree / stage / socrates / safety / citation / status / error / done。
  /// 与 sendMessage 并存，按需切换：流式只负责 SP 实时回复，结束问诊 / OSCE 流程仍走同步接口。
  ///
  /// 流式安全：连接级重试 + 空流字段兜底仿照 companionStream；不做整条重发避免用户看到两遍拼接。
  Stream<AskStreamEvent> chatRoomStream({
    required int sessionId,
    required String message,
    int connectRetries = 2,
    CancelToken? cancelToken,
  }) async* {
    final body = <String, dynamic>{'message': message};
    for (var attempt = 0; attempt <= connectRetries; attempt++) {
      var yielded = false;
      try {
        final opts = Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          // 流式 SSE 客户端连接可最长挂 5 分钟；后端 AI 中台 chat_stream 镜像处理 0 超时。
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 15),
        );
        final resp = await _dio.post<dynamic>(
          '/api/v1/student/sessions/$sessionId/chat/stream',
          data: body,
          options: opts,
          cancelToken: cancelToken,
        );
        if (resp.data is! ResponseBody) {
          yield const AskStreamEvent('error', {'message': '流式响应格式异常'});
          return;
        }
        final rs = resp.data as ResponseBody;
        var event = '';
        final buf = StringBuffer();
        await for (final line
            in utf8.decoder.bind(rs.stream).transform(const LineSplitter())) {
          if (line.startsWith(':')) continue; // SSE 心跳注释行
          if (line.isEmpty) {
            if (event.isNotEmpty) {
              final data = _tryParseJson(buf.toString());
              yield AskStreamEvent(event, data);
              yielded = true;
              if (event == 'done') return;
              event = '';
              buf.clear();
            }
            continue;
          }
          if (line.startsWith('event:')) {
            event = line.substring('event:'.length).trim();
            buf.clear();
          } else if (line.startsWith('data:')) {
            var d = line.substring('data:'.length);
            if (d.startsWith(' ')) d = d.substring(1);
            if (buf.isNotEmpty) buf.write('\n');
            buf.write(d);
          }
        }
        if (!yielded) {
          yield const AskStreamEvent('error', {'message': '未收到 AI 回复，请重试'});
        }
        return;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        final retryable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout;
        if (!retryable || yielded || attempt >= connectRetries) {
          yield const AskStreamEvent('error', {'message': '连接问诊服务失败，请检查网络'});
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }

  /// 上传问诊影像（后端本地目录存储，返回 url）
  Future<ApiResponse<Map<String, dynamic>>> uploadImage({
    required int sessionId,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/sessions/$sessionId/image',
        data: formData,
        options: _uploadOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 影像 AI 读图分析（未配置模型时返回降级提示）
  Future<ApiResponse<Map<String, dynamic>>> analyzeImage({
    required int sessionId,
    required String imageUrl,
    List<double>? imageBbox,
    String? studentNote,
  }) async {
    try {
      final body = <String, dynamic>{'imageUrl': imageUrl};
      if (imageBbox != null && imageBbox.isNotEmpty) body['imageBbox'] = imageBbox;
      if (studentNote != null && studentNote.isNotEmpty) body['studentNote'] = studentNote;
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/sessions/$sessionId/image/analyze',
        data: body,
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教材分页列表
  Future<ApiResponse<Map<String, dynamic>>> getTextbooks({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? keyword,
  }) async {
    try {
      final params = <String, dynamic>{'pageNum': pageNum, 'pageSize': pageSize};
      if (department != null && department.isNotEmpty) params['department'] = department;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/textbooks',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教材详情
  Future<ApiResponse<Map<String, dynamic>>> getTextbookDetail(int id) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/textbooks/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 教材科室分类列表（筛选入口）
  Future<ApiResponse<List<dynamic>>> getTextbookDepartments() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/textbooks/departments');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 基础题分页列表
  Future<ApiResponse<Map<String, dynamic>>> getQuestions({
    int pageNum = 1,
    int pageSize = 20,
    String? department,
    String? knowledgeTag,
    int? difficulty,
    String? questionType,
  }) async {
    try {
      final params = <String, dynamic>{'pageNum': pageNum, 'pageSize': pageSize};
      if (department != null && department.isNotEmpty) params['department'] = department;
      if (knowledgeTag != null && knowledgeTag.isNotEmpty) params['knowledgeTag'] = knowledgeTag;
      if (difficulty != null) params['difficulty'] = difficulty;
      if (questionType != null && questionType.isNotEmpty) params['questionType'] = questionType;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/questions',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 提交基础题答案
  Future<ApiResponse<Map<String, dynamic>>> submitQuestion({
    required int questionId,
    required String selectedAnswer,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/questions/submit',
        data: {'questionId': questionId, 'selectedAnswer': selectedAnswer},
        options: _mediumOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的训练统计
  Future<ApiResponse<Map<String, dynamic>>> getQuestionStats() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/questions/stats');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 科室（模块）列表，用于刷题入口
  Future<ApiResponse<List<dynamic>>> getQuestionDepartments() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/questions/departments');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 知识点列表，用于题库筛选
  Future<ApiResponse<List<dynamic>>> getQuestionKnowledgeTags() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/questions/knowledge-tags');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 按科室刷题（单页返回，逐题/翻页）
  Future<ApiResponse<Map<String, dynamic>>> getQuestionsByDepartment({
    int pageNum = 1,
    int pageSize = 1,
    required String department,
    int? difficulty,
  }) async {
    try {
      final params = <String, dynamic>{
        'pageNum': pageNum,
        'pageSize': pageSize,
        'department': department,
      };
      if (difficulty != null) params['difficulty'] = difficulty;
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/questions/by-department',
        queryParameters: params,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 单个薄弱知识点推荐（基础题 + 教材）
  Future<ApiResponse<Map<String, dynamic>>> getRecommendation(String knowledgeTag) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/recommend/weakness',
        queryParameters: {'knowledgeTag': knowledgeTag},
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 全部薄弱知识点推荐列表
  Future<ApiResponse<List<dynamic>>> getRecommendations() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/recommend/weaknesses');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 全局检索（教材 + 基础题 + 病例）
  Future<ApiResponse<Map<String, dynamic>>> searchResources(String keyword) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/recommend/search',
        queryParameters: {'keyword': keyword},
        options: _mediumOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 以图搜图（P1-4 多模态影像检索）：上传医学图片，检索教材影像知识库
  Future<ApiResponse<Map<String, dynamic>>> searchKnowledgeByImage({
    required String imageBase64,
    String? text,
    int topK = 5,
    String? subject,
  }) async {
    try {
      final body = <String, dynamic>{'imageBase64': imageBase64, 'topK': topK};
      if (text != null && text.isNotEmpty) body['text'] = text;
      if (subject != null && subject.isNotEmpty) body['subject'] = subject;
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/knowledge/search-image',
        data: body,
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 获取教材原图字节（P1-4 影像检索结果回显）
  Future<Uint8List?> getKnowledgeImageBytes(String imageKey) async {
    try {
      final resp = await _dio.get<List<int>>(
        '/api/v1/knowledge/images/${Uri.encodeComponent(imageKey)}',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      log('getKnowledgeImageBytes failed: $e', name: 'student_api');
      return null;
    }
  }

  /// 薄弱点学情诊断（统计 + AI 归因合并，供推荐页「AI 诊断」区块）
  Future<ApiResponse<Map<String, dynamic>>> getAiDiagnosis() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/recommend/diagnosis',
        options: _aiOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 组卷任务（提交生成任务，异步落在服务端）
  Future<ApiResponse<Map<String, dynamic>>> submitPaperTask({
    int count = 10, int? difficulty, List<String> focusTags = const [],
    List<String> questionTypes = const [], List<String> departments = const [],
    List<String> knowledgeTags = const [],
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>('/api/v1/student/paper/tasks', data: {
        'count': count,
        if (difficulty != null) 'difficulty': difficulty,
        'focusTags': focusTags,
        if (questionTypes.isNotEmpty) 'questionTypes': questionTypes,
        if (departments.isNotEmpty) 'departments': departments,
        if (knowledgeTags.isNotEmpty) 'knowledgeTags': knowledgeTags,
      },
        options: _mediumOptions,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 查询 AI 组卷任务结果
  Future<ApiResponse<Map<String, dynamic>>> getPaperTask(String taskId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/paper/tasks/$taskId', options: _mediumOptions);
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 学伴对话（P1-2，学习陪伴）· 同步（增强：指数退避重试 + 兜底错误）
  Future<ApiResponse<Map<String, dynamic>>> companion({
    required String message, List<Map<String, String>> history = const [],
    int? conversationId, int retries = 2,
  }) async {
    final body = <String, dynamic>{'message': message, 'history': history};
    if (conversationId != null) body['conversationId'] = conversationId;
    final opts = Options(receiveTimeout: const Duration(seconds: 60), sendTimeout: const Duration(seconds: 15));
    Object? lastErr;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final resp = await _dio.post<Map<String, dynamic>>('/api/v1/student/companion', data: body, options: opts);
        return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
      } on DioException catch (e) {
        lastErr = e;
        final retryable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout || ((e.response?.statusCode ?? 0) >= 500);
        if (!retryable) break;
        if (attempt < retries) { await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1))); continue; }
      }
    }
    final e = lastErr;
    return ApiResponse(code: -1, message: e is DioException ? _mapError(e) : '请求失败，请稍后重试');
  }

  /// 学伴会话列表（分页）
  Future<ApiResponse<Map<String, dynamic>>> getCompanionConversations({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/companion/conversations',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 新建学伴会话
  Future<ApiResponse<Map<String, dynamic>>> createCompanionConversation({
    required String title,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/companion/conversations',
        data: {'title': title},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 重命名学伴会话
  Future<ApiResponse<Map<String, dynamic>>> renameCompanionConversation(int id, String title) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/student/companion/conversations/$id',
        data: {'title': title},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 删除学伴会话
  Future<ApiResponse<Map<String, dynamic>>> deleteCompanionConversation(int id) async {
    try {
      final resp = await _dio.delete<Map<String, dynamic>>('/api/v1/student/companion/conversations/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 学伴会话消息分页列表
  Future<ApiResponse<Map<String, dynamic>>> getCompanionMessages(int conversationId, {
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/companion/conversations/$conversationId/messages',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 新增学伴会话消息
  Future<ApiResponse<Map<String, dynamic>>> createCompanionMessage(int conversationId, {
    String? sender,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final body = <String, dynamic>{'content': content};
      if (sender != null && sender.isNotEmpty) body['sender'] = sender;
      if (imageUrl != null && imageUrl.isNotEmpty) body['imageUrl'] = imageUrl;
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/companion/conversations/$conversationId/messages',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 学伴对话 · 流式（SSE，增强：连接级重试 + 空流字段兜底）
  /// 以 text/event-stream 消费后端 /companion/stream，按事件逐条产出
  /// （message: 增量文本；status: 降级提示；safety/error/done）。
  Stream<AskStreamEvent> companionStream({
    required String message, List<Map<String, String>> history = const [],
    String? imageUrl, int? conversationId, int connectRetries = 2, CancelToken? cancelToken,
  }) async* {
    final body = <String, dynamic>{'message': message, 'history': history};
    if (imageUrl != null && imageUrl.isNotEmpty) body['imageUrl'] = imageUrl;
    if (conversationId != null) body['conversationId'] = conversationId;
    for (var attempt = 0; attempt <= connectRetries; attempt++) {
      var yielded = false;
      try {
        final opts = Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 15),
        );
        final resp = await _dio.post<dynamic>(
          '/api/v1/student/companion/stream',
          data: body,
          options: opts,
          cancelToken: cancelToken,
        );
        if (resp.data is! ResponseBody) {
          yield const AskStreamEvent('error', {'message': '流式响应格式异常'});
          return;
        }
        final rs = resp.data as ResponseBody;
        var event = '';
        final buf = StringBuffer();
        await for (final line
            in utf8.decoder.bind(rs.stream).transform(const LineSplitter())) {
          if (line.startsWith(':')) continue; // SSE 心跳注释行，忽略
          if (line.isEmpty) {
            if (event.isNotEmpty) {
              final data = _tryParseJson(buf.toString());
              yield AskStreamEvent(event, data);
              yielded = true;
              if (event == 'done') return;
              event = '';
              buf.clear();
            }
            continue;
          }
          if (line.startsWith('event:')) {
            // 新事件开始：清空上一帧残留，避免只有 event 无 data 时串帧
            event = line.substring('event:'.length).trim();
            buf.clear();
          } else if (line.startsWith('data:')) {
            var d = line.substring('data:'.length);
            if (d.startsWith(' ')) d = d.substring(1);
            if (buf.isNotEmpty) buf.write('\n'); // 多行 data 按规范换行连接
            buf.write(d);
          }
        }
        // 流被上游正常关闭但未收到 done：只要确实收到过内容就视为正常结束。
        // 此前用一个恒为 true 的判断（!stream.isBroadcast）误报「连接中断」。
        if (!yielded) {
          yield const AskStreamEvent('error', {'message': '未收到学伴回复，请重试'});
        }
        return;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        final retryable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout;
        // 已产出过内容再断流时不再整条重发，否则用户会看到两遍拼接的回答
        if (!retryable || yielded || attempt >= connectRetries) {
          yield const AskStreamEvent('error', {'message': '连接学伴服务失败，请检查网络'});
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }

  // ================= AI 学伴偏好 & 长期记忆（仅学伴，标准 SP 不受影响） =================

  /// 获取 AI 学伴偏好（语气档位 + 记忆开关，服务端持久化，多端一致）
  Future<ApiResponse<Map<String, dynamic>>> getCompanionPreferences() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/preferences');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 更新 AI 学伴偏好（按需传 aiTone / aiMemoryEnabled）
  Future<ApiResponse<Map<String, dynamic>>> updateCompanionPreferences({
    String? aiTone,
    bool? aiMemoryEnabled,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (aiTone != null && aiTone.isNotEmpty) body['aiTone'] = aiTone;
      if (aiMemoryEnabled != null) body['aiMemoryEnabled'] = aiMemoryEnabled;
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/v1/student/preferences',
        data: body,
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// AI 学伴长期记忆列表（分页，按时间倒序）
  Future<ApiResponse<Map<String, dynamic>>> getCompanionMemories({
    int pageNum = 1,
    int pageSize = 50,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/memories',
        queryParameters: {'pageNum': pageNum, 'pageSize': pageSize},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 删除一条 AI 学伴记忆
  Future<ApiResponse<Map<String, dynamic>>> deleteCompanionMemory(int id) async {
    try {
      final resp = await _dio.delete<Map<String, dynamic>>('/api/v1/student/memories/$id');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 清空全部 AI 学伴记忆
  Future<ApiResponse<Map<String, dynamic>>> clearCompanionMemories() async {
    try {
      final resp = await _dio.delete<Map<String, dynamic>>('/api/v1/student/memories/clear');
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  static Map<String, dynamic> _tryParseJson(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// 学习任务聚合列表（备课资料任务 + 病例作业）
  Future<ApiResponse<List<dynamic>>> getStudentTasks() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/tasks');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 标记资料任务完成（幂等；完成后从待办与课程角标清除）
  Future<ApiResponse<bool>> completeLessonTask(int publishId) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/tasks/lesson-tasks/$publishId/complete',
      );
      return ApiResponse.fromJson(resp.data!, (d) => true);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 通过邀请码加入班级（后端 R<TeachingClassVO>）
  Future<ApiResponse<Map<String, dynamic>>> joinClass(String inviteCode) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/classes/join',
        data: {'inviteCode': inviteCode},
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的课程（已加入班级的多对多列表）
  Future<ApiResponse<List<dynamic>>> getMyClasses() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/classes/my-classes',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 班级详情（教师分享的资料与作业，闭环）
  Future<ApiResponse<Map<String, dynamic>>> getClassDetail(int classId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/student/classes/$classId',
      );
      return ApiResponse.fromJson(resp.data!, (d) => d as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 发起批阅申诉（P2-1）
  Future<ApiResponse<int>> createAppeal({
    required int instanceId,
    required String reason,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/student/appeals/$instanceId',
        data: {'reason': reason},
      );
      return ApiResponse.fromJson(resp.data!, (d) => (d as num).toInt());
    } on DioException catch (e) {
      return ApiResponse(code: -1, message: _mapError(e));
    }
  }

  /// 我的申诉列表（P2-1）
  Future<ApiResponse<List<dynamic>>> myAppeals() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/student/appeals/my');
      return ApiResponse.fromJson(resp.data!, (d) => d as List<dynamic>);
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
