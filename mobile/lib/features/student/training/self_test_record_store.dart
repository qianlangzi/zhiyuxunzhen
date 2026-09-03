import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 一条自测记录（本地保存，后端接口补齐前用于历史与折线图）
class SelfTestRecord {
  final int epoch; // 完成时间戳
  final double score; // 得分
  final double totalScore; // 满分
  final int correct;
  final int count;
  final double scorePerQuestion;
  final String? source; // AI / RULE
  final List<String> questionTypes;

  const SelfTestRecord({
    required this.epoch,
    required this.score,
    required this.totalScore,
    required this.correct,
    required this.count,
    required this.scorePerQuestion,
    this.source,
    this.questionTypes = const [],
  });

  double get accuracy => count == 0 ? 0.0 : correct / count;

  Map<String, dynamic> toJson() => {
        'epoch': epoch,
        'score': score,
        'totalScore': totalScore,
        'correct': correct,
        'count': count,
        'scorePerQuestion': scorePerQuestion,
        'source': source,
        'questionTypes': questionTypes,
      };

  factory SelfTestRecord.fromJson(Map<String, dynamic> m) => SelfTestRecord(
        epoch: (m['epoch'] as num?)?.toInt() ?? 0,
        score: (m['score'] as num?)?.toDouble() ?? 0,
        totalScore: (m['totalScore'] as num?)?.toDouble() ?? 0,
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        count: (m['count'] as num?)?.toInt() ?? 0,
        scorePerQuestion: (m['scorePerQuestion'] as num?)?.toDouble() ?? 2,
        source: m['source'] as String?,
        questionTypes:
            (m['questionTypes'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}

/// 自测记录本地仓库：写入 / 读取 / 清空
class SelfTestRecordStore {
  SelfTestRecordStore._();
  static const _key = 'self_test_records_v1';

  static Future<List<SelfTestRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SelfTestRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(SelfTestRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final arr = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        arr.addAll((jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    arr.insert(0, record.toJson());
    if (arr.length > 50) arr.removeRange(50, arr.length);
    await prefs.setString(_key, jsonEncode(arr));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}