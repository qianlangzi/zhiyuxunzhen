import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 成长数据统一计算模型
///
/// 此前「连续天数 / 累计训练 / OSCE 均分」三套算法分别硬编码在
/// 成长页、学习档案页、我的页三处，口径不一致且重复。
/// 现统一收敛到此处：输入学情概览 `overview`，输出 [GrowthStats]。
@immutable
class GrowthStats {
  const GrowthStats({
    required this.streakDays,
    required this.longestStreakDays,
    required this.totalTrainings,
    required this.thisMonthTrainings,
    required this.activeDays,
    required this.osceAvg,
    required this.entries,
    this.activityDays = const [],
  });

  /// 从学情概览构建（GET /student/review-report/overview）
  ///
  /// [overview] 为 null 或字段缺失时退化为全零，绝不抛异常。
  factory GrowthStats.fromOverview(Map<String, dynamic>? overview) {
    final days = <Map<String, dynamic>>[];
    final rawDays = overview?['activityDays'] as List<dynamic>?;
    if (rawDays != null) {
      for (final d in rawDays) {
        if (d is Map) {
          days.add(Map<String, dynamic>.from(d));
        }
      }
    }

    final byDate = <DateTime, int>{};
    var total = 0;
    for (final d in days) {
      final dateStr = d['date'] as String? ?? '';
      final count = (d['completedCount'] as num?)?.toInt() ?? 0;
      total += count;
      if (dateStr.isEmpty || count <= 0) continue;
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) continue;
      byDate[DateTime(parsed.year, parsed.month, parsed.day)] = count;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 本月完成次数
    var thisMonth = 0;
    for (final e in byDate.entries) {
      if (e.key.year == now.year && e.key.month == now.month) {
        thisMonth += e.value;
      }
    }

    // 最长连续天数
    var longest = 0;
    var run = 0;
    final sorted = byDate.keys.toList()..sort();
    DateTime? prev;
    for (final d in sorted) {
      if (prev != null && d.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = d;
    }

    // 当前连续天数：今天没练则从昨天起算，否则为 0
    var streak = 0;
    if (byDate.isNotEmpty) {
      var anchor = byDate.containsKey(today)
          ? today
          : today.subtract(const Duration(days: 1));
      if (byDate.containsKey(anchor)) {
        while (byDate.containsKey(anchor)) {
          streak++;
          anchor = anchor.subtract(const Duration(days: 1));
        }
      }
    }

    // 能力维度
    final entries = <AbilityEntry>[];
    final ability = overview?['abilityScores'] as Map<String, dynamic>?;
    if (ability != null) {
      for (final e in ability.entries) {
        final score = (e.value as num?)?.toDouble() ?? 0.0;
        entries.add(AbilityEntry(key: e.key, label: labelOf(e.key), score: score));
      }
      entries.sort((a, b) => a.score.compareTo(b.score));
    }

    final osceAvg = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.score).reduce((a, b) => a + b) / entries.length;

    return GrowthStats(
      streakDays: streak,
      longestStreakDays: longest,
      totalTrainings: total,
      thisMonthTrainings: thisMonth,
      activeDays: byDate.length,
      osceAvg: osceAvg,
      entries: entries,
      activityDays: days,
    );
  }

  /// 当前连续训练天数
  final int streakDays;

  /// 历史最长连续天数
  final int longestStreakDays;

  /// 累计训练次数（全部 activityDays 求和）
  final int totalTrainings;

  /// 本月训练次数
  final int thisMonthTrainings;

  /// 有训练记录的自然日数
  final int activeDays;

  /// OSCE 各维度平均分
  final double osceAvg;

  /// 能力维度（升序，最弱在前）
  final List<AbilityEntry> entries;

  /// 原始活动数据，供热力图复用
  final List<Map<String, dynamic>> activityDays;

  bool get hasAbility => entries.isNotEmpty;
  bool get hasActivity => activityDays.isNotEmpty;

  /// 最弱维度（可能为 null）
  AbilityEntry? get weakest => entries.isEmpty ? null : entries.first;

  /// 最强维度
  AbilityEntry? get strongest => entries.isEmpty ? null : entries.last;

  /// 低于 70 分的薄弱维度数
  int get weakCount => entries.where((e) => e.score < 70).length;

  /// 维度英文 key -> 中文标签
  static String labelOf(String key) {
    switch (key) {
      case 'history':
        return '病史采集';
      case 'logic':
        return '诊断逻辑';
      case 'communication':
        return '沟通技巧';
      case 'humanity':
        return '人文关怀';
      case 'exam':
        return '检查决策';
      case 'record':
        return '文书规范';
      default:
        return key;
    }
  }

  /// 根据分数取语义色：<70 朱砂，<85 琥珀，其余主色
  Color colorOf(BuildContext context, double score) {
    if (score < 70) return AppColors.vermilionOf(context);
    if (score < 85) return AppColors.amberOf(context);
    return AppColors.primaryOf(context);
  }
}

/// 单个能力维度
@immutable
class AbilityEntry {
  const AbilityEntry({
    required this.key,
    required this.label,
    required this.score,
  });

  final String key;
  final String label;
  final double score;

  /// 雷达图用的极短标签（取前两字：病史采集 → 病史）
  String get shortLabel => label.length > 2 ? label.substring(0, 2) : label;
}

/// 刷题训练统计（GET /student/questions/stats）
///
/// 聚合「已刷、答对、答错、正确率」总览 + 分科室（模块）占比，
/// 供成长页「训练解析」卡做答对/答错与模块分布可视化。
@immutable
class QuestionStats {
  const QuestionStats({
    required this.totalAnswered,
    required this.correctCount,
    required this.accuracy,
    this.totalCount = 0,
    this.modules = const [],
  });

  /// 从接口返回构造；无数据/字段缺失时退化为全零，绝不抛异常。
  factory QuestionStats.fromApi(Map<String, dynamic>? data) {
    final total = (data?['totalAnswered'] as num?)?.toInt() ?? 0;
    final correct = (data?['correctCount'] as num?)?.toInt() ?? 0;
    final accuracy = (data?['accuracy'] as num?)?.toDouble() ?? 0.0;
    final bankTotal = (data?['totalCount'] as num?)?.toInt() ?? 0;

    final modules = <ModuleStat>[];
    final raw = data?['byDepartment'] as List<dynamic>?;
    if (raw != null) {
      for (final m in raw) {
        if (m is! Map) continue;
        final answered = (m['answered'] as num?)?.toInt() ?? 0;
        modules.add(ModuleStat(
          name: (m['department'] as String?)?.trim().isNotEmpty == true
              ? (m['department'] as String).trim()
              : '未分类',
          answered: answered,
          correct: (m['correct'] as num?)?.toInt() ?? 0,
          accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0.0,
          share: total <= 0 ? 0.0 : answered / total,
        ),);
      }
      // 做题量降序，把重点模块排前面
      modules.sort((a, b) => b.answered.compareTo(a.answered));
    }

    return QuestionStats(
      totalAnswered: total,
      correctCount: correct,
      accuracy: accuracy,
      totalCount: bankTotal,
      modules: modules,
    );
  }

  /// 累计已刷题数（去重题）
  final int totalAnswered;

  /// 累计答对题数
  final int correctCount;

  /// 总体正确率 0.00 ~ 1.00
  final double accuracy;

  /// 题库题目总量（用于展示「题库共 N 题」）
  final int totalCount;

  /// 按科室（模块）聚合，做题量降序
  final List<ModuleStat> modules;

  /// 答错题数
  int get wrongCount => totalAnswered - correctCount;

  /// 是否已有刷题记录
  bool get hasData => totalAnswered > 0;
}

/// 单个模块（科室）的刷题统计
@immutable
class ModuleStat {
  const ModuleStat({
    required this.name,
    required this.answered,
    required this.correct,
    required this.accuracy,
    required this.share,
  });

  final String name;
  final int answered;
  final int correct;

  /// 该模块正确率 0.00 ~ 1.00
  final double accuracy;

  /// 该模块做题量占总量的占比 0.00 ~ 1.00
  final double share;
}
