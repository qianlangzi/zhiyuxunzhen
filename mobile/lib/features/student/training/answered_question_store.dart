import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 题库「已做」题目的本地记录（持久化问题 id）
///
/// 后端题库接口暂未返回 answered 字段，先以前端本地记录兜底标记已做/未做。
class AnsweredQuestionStore {
  AnsweredQuestionStore._();
  static const _key = 'answered_question_ids_v1';

  static Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> add(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await load();
    set.add(id);
    await prefs.setString(_key, jsonEncode(set.toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}