import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyu/data/models.dart';

import '../../core/config/app_config.dart';
import '../sources/api_client.dart';
import '../sources/api_exception.dart';
import '../sources/mock_data.dart';

class CaseRepository {
  CaseRepository(this._dio);

  final Dio _dio;

  List<CaseModel> all() => MockData.cases.toList();
  CaseModel daily() => MockData.dailyCase;
  List<MarketCaseModel> market() => MockData.marketCases.toList();

  CaseModel? byId(String id) {
    for (final CaseModel item in MockData.cases) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<List<CaseModel>> fetchCases() async {
    if (AppConfig.mockEnabled) return all();
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/v1/case-market/list',
        queryParameters: <String, dynamic>{'pageNum': 1, 'pageSize': 50},
      );
      final Map<String, dynamic> page = unwrapEnvelope(response.data);
      final List<dynamic> rows = page['list'] is List
          ? List<dynamic>.from(page['list'] as List)
          : const <dynamic>[];
      return rows
          .whereType<Map>()
          .map((Map row) => _caseFromList(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<CaseModel?> fetchById(String id) async {
    if (AppConfig.mockEnabled) {
      final CaseModel? listed = byId(id);
      if (listed != null) return listed;
      return daily().id == id ? daily() : null;
    }
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/case-market/$id');
      return _caseFromDetail(unwrapEnvelope(response.data));
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<CaseModel?> fetchDaily() async {
    if (AppConfig.mockEnabled) return daily();
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/student/daily-cases/today');
      final Map<String, dynamic>? data = unwrapNullableEnvelope(response.data);
      if (data == null) return null;
      final List<String> options = _stringList(data['optionsJson']);
      return CaseModel(
        id: _int(data['caseId']).toString(),
        scheduleId: _int(data['scheduleId']),
        title: data['caseTitle']?.toString() ?? '今日病例',
        chief: data['question']?.toString() ?? '',
        summary: data['question']?.toString(),
        tags: const <String>[],
        department: data['department']?.toString() ?? '',
        difficulty: _difficulty(data['difficulty']),
        duration: '',
        referenceCount: 0,
        rating: 0,
        certified: true,
        options: options,
        source: data['textbookRef']?.toString(),
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> submitDaily({
    required int scheduleId,
    required String answer,
  }) async {
    if (AppConfig.mockEnabled) {
      return <String, dynamic>{
        'correct': true,
        'explanation': '活动诱发、休息缓解是稳定型心绞痛的典型线索。',
        'degraded': false,
      };
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/student/daily-cases/submit',
        data: <String, dynamic>{'scheduleId': scheduleId, 'answer': answer},
      );
      return unwrapEnvelope(response.data);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<MarketCaseModel>> fetchMarket() async {
    if (AppConfig.mockEnabled) return market();
    final List<CaseModel> cases = await fetchCases();
    return cases
        .map((CaseModel item) => MarketCaseModel(
              id: item.id,
              title: item.title,
              author: '',
              department: item.department,
              difficulty: item.difficulty,
              referenceCount: item.referenceCount,
              rating: item.rating,
              certified: item.certified,
            ))
        .toList();
  }

  Future<int> quoteCase(String id) async {
    if (AppConfig.mockEnabled) return int.tryParse(id) ?? 1;
    try {
      final Response<dynamic> response =
          await _dio.post<dynamic>('/api/v1/case-market/$id/quote');
      final dynamic body = response.data;
      if (body is Map && body['code'] == 0 && body['data'] is num) {
        return (body['data'] as num).toInt();
      }
      throw const ApiException(
        message: '引用病例返回格式异常',
        kind: ApiErrorKind.contract,
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<CaseModel>> fetchTeacherCases() async {
    if (AppConfig.mockEnabled) return all();
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/v1/teacher/cases',
        queryParameters: <String, dynamic>{'pageNum': 1, 'pageSize': 100},
      );
      final Map<String, dynamic> page = unwrapEnvelope(response.data);
      final List<dynamic> rows = page['list'] is List
          ? List<dynamic>.from(page['list'] as List)
          : const <dynamic>[];
      return rows.whereType<Map>().map((Map row) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(row);
        return CaseModel(
          id: _int(item['id']).toString(),
          title: item['title']?.toString() ?? '未命名病例',
          chief: '',
          tags: const <String>[],
          department: item['department']?.toString() ?? '',
          difficulty: _difficulty(item['difficulty']),
          duration: '',
          referenceCount: _int(item['referenceCount']),
          rating: _double(item['ratingAvg']),
          certified: _int(item['adminAuditStatus']) == 2,
        );
      }).toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<int> createTeacherCase({
    required String title,
    required String department,
    required int difficulty,
    required Map<String, dynamic> patientProfile,
    required String hiddenDisease,
    required List<String> standardPath,
    required List<String> tags,
  }) async {
    if (AppConfig.mockEnabled) return 1;
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/teacher/cases',
        data: <String, dynamic>{
          'title': title,
          'department': department,
          'difficulty': difficulty,
          'patientProfile': jsonEncode(patientProfile),
          'hiddenDisease': hiddenDisease,
          'standardPathJson': jsonEncode(standardPath),
          'presetExams': '[]',
          'knowledgeTags': jsonEncode(tags),
        },
      );
      final dynamic data = _unwrapData(response.data);
      if (data is num) return data.toInt();
      throw const ApiException(message: '创建病例返回格式异常');
    } catch (error) {
      throw mapDioException(error);
    }
  }

  CaseModel _caseFromList(Map<String, dynamic> data) {
    return CaseModel(
      id: _int(data['id']).toString(),
      title: data['title']?.toString() ?? '未命名病例',
      chief: '',
      tags: _stringList(data['knowledgeTags']),
      department: data['department']?.toString() ?? '',
      difficulty: _difficulty(data['difficulty']),
      duration: '',
      referenceCount: _int(data['referenceCount']),
      rating: _double(data['ratingAvg']),
      certified: true,
    );
  }

  CaseModel _caseFromDetail(Map<String, dynamic> data) {
    final Map<String, dynamic> profile = _jsonMap(data['patientProfile']);
    final String chief = profile['chiefComplaint']?.toString() ?? '';
    return CaseModel(
      id: _int(data['id']).toString(),
      title: data['title']?.toString() ?? '未命名病例',
      chief: chief,
      summary: chief,
      tags: _stringList(data['knowledgeTags']),
      department: data['department']?.toString() ?? '',
      difficulty: _difficulty(data['difficulty']),
      duration: '',
      referenceCount: _int(data['referenceCount']),
      rating: _double(data['ratingAvg']),
      certified: true,
    );
  }
}

class LearningRepository {
  LearningRepository([this._dio]);

  final Dio? _dio;

  List<ChatMessage> chat() => MockData.chatMessages.toList();
  List<ReasoningNode> reasoning() => MockData.reasoningNodes.toList();
  List<AbilityScore> abilities() => MockData.abilityScores.toList();
  List<LearningPathItem> learningPath() => MockData.learningPath.toList();
  List<MistakeItem> mistakes() => MockData.mistakes.toList();
  List<HeatmapDay> heatmap() => MockData.heatmapDays.toList();

  Future<List<MistakeItem>> fetchMistakes() async {
    if (AppConfig.mockEnabled || _dio == null) return mistakes();
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/api/v1/student/mistakes',
        queryParameters: <String, dynamic>{'pageNum': 1, 'pageSize': 50},
      );
      final Map<String, dynamic> page = unwrapEnvelope(response.data);
      final List<dynamic> rows = page['list'] is List
          ? List<dynamic>.from(page['list'] as List)
          : const <dynamic>[];
      return rows.whereType<Map>().map((Map row) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        return MistakeItem(
          type: _mistakeType(data['mistakeType']?.toString()),
          title: data['caseTitle']?.toString() ?? '未命名病例',
          tag: data['knowledgeTag']?.toString() ?? '未分类',
          evidence: _evidence(data['evidenceJson']),
          reviewed: _int(data['resolvedStatus']) > 0,
        );
      }).toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<AssignmentModel>> fetchStudentAssignments() async {
    try {
      final Response<dynamic> response = await _dio!.get<dynamic>(
        '/api/v1/student/assignments/my',
        queryParameters: <String, dynamic>{'pageNum': 1, 'pageSize': 100},
      );
      final Map<String, dynamic> page = unwrapEnvelope(response.data);
      final List<dynamic> rows = page['list'] is List
          ? List<dynamic>.from(page['list'] as List)
          : const <dynamic>[];
      return rows.whereType<Map>().map((Map row) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(row);
        return AssignmentModel(
          id: _int(item['instanceId']),
          caseId: _int(item['caseId']),
          title: item['assignmentTitle']?.toString() ?? '未命名作业',
          className: item['caseTitle']?.toString() ?? '',
          submitted: _int(item['status']) >= 2 ? 1 : 0,
          total: 1,
          due: _dateLabel(item['deadline']),
          status: _studentAssignmentStatus(_int(item['status'])),
          requireRecord: true,
          variable: '按分配参数训练',
        );
      }).toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> submitMedicalRecord({
    required int instanceId,
    required String text,
  }) async {
    if (AppConfig.mockEnabled || _dio == null) {
      return <String, dynamic>{'passed': true, 'status': 3};
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/student/assignments/$instanceId/submit-record',
        data: <String, dynamic>{'medicalRecordText': text},
      );
      return unwrapEnvelope(response.data);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<LearningOverview> fetchOverview() async {
    if (AppConfig.mockEnabled || _dio == null) {
      return LearningOverview(
        abilities: abilities(),
        activityDays: heatmap(),
        completedSessionCount: heatmap()
            .fold<int>(0, (total, item) => total + item.completedCount),
      );
    }
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/student/review-report/overview');
      final Map<String, dynamic> data = unwrapEnvelope(response.data);
      final Map<String, dynamic> scores = data['abilityScores'] is Map
          ? Map<String, dynamic>.from(data['abilityScores'] as Map)
          : const <String, dynamic>{};
      final List<AbilityScore> abilityItems = scores.entries
          .map((entry) => AbilityScore(
                label: _abilityLabel(entry.key),
                value: _int(entry.value).clamp(0, 100),
              ))
          .toList();
      final List<dynamic> rows = data['activityDays'] is List
          ? List<dynamic>.from(data['activityDays'] as List)
          : const <dynamic>[];
      final List<HeatmapDay> days = rows
          .whereType<Map>()
          .map((Map row) {
            final Map<String, dynamic> item = Map<String, dynamic>.from(row);
            final int count = _int(item['completedCount']);
            return HeatmapDay(
              date: item['date']?.toString() ?? '',
              value: count.clamp(0, 4),
              completedCount: count,
              activities: const <String>['病例训练'],
            );
          })
          .where((item) => item.date.isNotEmpty)
          .toList();
      return LearningOverview(
        abilities: abilityItems,
        activityDays: days,
        completedSessionCount: _int(data['completedSessionCount']),
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }
}

class TeachingRepository {
  TeachingRepository([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  List<AssignmentModel> assignments() => MockData.assignments.toList();
  List<ReviewItem> reviewQueue() => MockData.reviewQueue.toList();
  List<WeaknessItem> weakness() => MockData.weakness.toList();
  List<FormatShieldRule> formatRules() => MockData.formatShieldRules.toList();

  Future<List<AssignmentModel>> fetchAssignments() async {
    if (AppConfig.mockEnabled) return assignments();
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/teacher/assignments');
      final dynamic raw = _unwrapData(response.data);
      final List<dynamic> rows = raw is List ? raw : const <dynamic>[];
      return rows.whereType<Map>().map((Map row) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(row);
        final List<String> classes = _stringList(item['classNames']);
        return AssignmentModel(
          id: _int(item['id']),
          caseId: _int(item['caseId']),
          title: item['title']?.toString() ?? '未命名作业',
          className: classes.isEmpty ? '未指定班级' : classes.join('、'),
          submitted: _int(item['submittedCount']),
          total: _int(item['studentCount']),
          due: _dateLabel(item['deadline']),
          status: _assignmentStatus(_int(item['status'])),
          requireRecord: item['requireMedicalRecord'] == true,
          variable: _hasValue(item['antiCheatVariables']) ? '已配置' : '关闭',
        );
      }).toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchClasses() async {
    if (AppConfig.mockEnabled) {
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': '临床 2203 班', 'studentCount': 30},
      ];
    }
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/teacher/assignments/classes');
      final dynamic raw = _unwrapData(response.data);
      return raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : <Map<String, dynamic>>[];
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<int> createAssignment({
    required int caseId,
    required int classId,
    required String title,
    required DateTime deadline,
  }) async {
    if (AppConfig.mockEnabled) return 1;
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/api/v1/teacher/assignments',
        data: <String, dynamic>{
          'caseId': caseId,
          'classIds': <int>[classId],
          'title': title,
          'deadline': deadline.toIso8601String(),
          'requireMedicalRecord': true,
          'allowLateSubmit': false,
        },
      );
      final dynamic data = _unwrapData(response.data);
      if (data is num) return data.toInt();
      throw const ApiException(
          message: '创建作业返回格式异常', kind: ApiErrorKind.contract);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<ReviewItem>> fetchReviews() async {
    if (AppConfig.mockEnabled) return reviewQueue();
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('/api/v1/teacher/reviews');
      final dynamic raw = _unwrapData(response.data);
      final List<dynamic> rows = raw is List ? raw : const <dynamic>[];
      return rows.whereType<Map>().map((Map row) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(row);
        final int status = _int(item['instanceStatus']);
        return ReviewItem(
          id: _int(item['instanceId']),
          reviewId: item['latestReviewId'] is num
              ? (item['latestReviewId'] as num).toInt()
              : null,
          student: item['studentName']?.toString() ?? '',
          assignment: item['assignmentTitle']?.toString() ?? '',
          score: _int(item['score']),
          issue: item['issue']?.toString() ?? '暂无批阅说明',
          status: status == 5
              ? '已复核'
              : status == 4
                  ? '待复核'
                  : 'AI 批阅中',
        );
      }).toList();
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> overrideReview(ReviewItem item, String comment) async {
    if (AppConfig.mockEnabled) return;
    if (item.reviewId == null) {
      throw const ApiException(message: 'AI 批阅尚未完成，暂不能复核');
    }
    try {
      await _dio.post<dynamic>(
        '/api/v1/teacher/reviews/${item.id}/override',
        data: <String, dynamic>{
          'overrideFromReviewId': item.reviewId,
          'totalScore': item.score,
          'reviewComment': comment.isEmpty ? '教师确认 AI 批阅结果' : comment,
          'mistakesJson': '[]',
        },
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }
}

final Provider<CaseRepository> caseRepositoryProvider =
    Provider<CaseRepository>((ref) => CaseRepository(ref.watch(dioProvider)));

final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>(
        (ref) => LearningRepository(ref.watch(dioProvider)));

final Provider<TeachingRepository> teachingRepositoryProvider =
    Provider<TeachingRepository>(
        (ref) => TeachingRepository(ref.watch(dioProvider)));

final FutureProvider<List<AssignmentModel>> teacherAssignmentListProvider =
    FutureProvider<List<AssignmentModel>>(
        (ref) => ref.watch(teachingRepositoryProvider).fetchAssignments());

final FutureProvider<List<ReviewItem>> teacherReviewListProvider =
    FutureProvider<List<ReviewItem>>(
        (ref) => ref.watch(teachingRepositoryProvider).fetchReviews());

final FutureProvider<List<CaseModel>> caseListProvider =
    FutureProvider<List<CaseModel>>(
        (ref) => ref.watch(caseRepositoryProvider).fetchCases());

final FutureProvider<List<CaseModel>> teacherCaseListProvider =
    FutureProvider<List<CaseModel>>(
        (ref) => ref.watch(caseRepositoryProvider).fetchTeacherCases());

final FutureProvider<List<MarketCaseModel>> caseMarketListProvider =
    FutureProvider<List<MarketCaseModel>>(
        (ref) => ref.watch(caseRepositoryProvider).fetchMarket());

final caseDetailProvider = FutureProvider.family<CaseModel?, String>(
    (ref, id) => ref.watch(caseRepositoryProvider).fetchById(id));

final FutureProvider<CaseModel?> dailyCaseProvider = FutureProvider<CaseModel?>(
    (ref) => ref.watch(caseRepositoryProvider).fetchDaily());

final FutureProvider<List<MistakeItem>> mistakeListProvider =
    FutureProvider<List<MistakeItem>>(
        (ref) => ref.watch(learningRepositoryProvider).fetchMistakes());

final FutureProvider<List<AssignmentModel>> studentAssignmentListProvider =
    FutureProvider<List<AssignmentModel>>((ref) =>
        ref.watch(learningRepositoryProvider).fetchStudentAssignments());

final FutureProvider<LearningOverview> learningOverviewProvider =
    FutureProvider<LearningOverview>(
        (ref) => ref.watch(learningRepositoryProvider).fetchOverview());

int _int(dynamic value) => value is num ? value.toInt() : 0;
double _double(dynamic value) => value is num ? value.toDouble() : 0;

dynamic _unwrapData(dynamic body) {
  if (body is! Map || body['code'] != 0) {
    throw ApiException(
        message:
            body is Map ? body['message']?.toString() ?? '请求失败' : '服务端返回格式异常');
  }
  return body['data'];
}

bool _hasValue(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  return text.isNotEmpty && text != '{}' && text != '[]' && text != 'null';
}

String _dateLabel(dynamic value) {
  final DateTime? date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '未设置';
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _assignmentStatus(int status) => switch (status) {
      0 => '草稿',
      2 => '已截止',
      _ => '进行中',
    };

String _studentAssignmentStatus(int status) => switch (status) {
      0 => '未开始',
      1 => '问诊中',
      2 => '格式打回',
      3 => 'AI 批阅中',
      4 => '待复核',
      5 => '已完成',
      _ => '未知',
    };

String _abilityLabel(String key) => switch (key.toLowerCase()) {
      'history' || 'history_taking' => '病史采集',
      'clinical_reasoning' || 'reasoning' => '临床推理',
      'communication' => '医患沟通',
      'record' || 'medical_record' => '病历书写',
      _ => key,
    };

String _difficulty(dynamic value) {
  return switch (_int(value)) { 1 => '基础', 3 => '高阶', _ => '标准' };
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((dynamic e) => e.toString()).toList();
  if (value is String && value.trim().isNotEmpty) {
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((dynamic e) => e.toString()).toList();
      }
    } catch (_) {
      return value.split(',').map((String e) => e.trim()).toList();
    }
  }
  return const <String>[];
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

String _evidence(dynamic value) {
  if (value == null) return '暂无证据说明';
  if (value is String) {
    final Map<String, dynamic> json = _jsonMap(value);
    if (json.isNotEmpty) return json.values.take(2).join('；');
    return value.length > 120 ? '${value.substring(0, 120)}…' : value;
  }
  return value.toString();
}

String _mistakeType(String? value) {
  return switch (value) {
    'diagnosis' => '诊断错误',
    'history' => '漏问病史',
    'exam' => '检查错误',
    'record' => '病历书写',
    'communication' => '沟通问题',
    _ => value ?? '未分类',
  };
}
