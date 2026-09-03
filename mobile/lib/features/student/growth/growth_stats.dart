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
}
