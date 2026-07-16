import 'package:flutter/foundation.dart';

import 'package:zhiyu/data/models.dart';

/// 最近三个月训练活动汇总
@immutable
class TrainingActivitySummary {
  const TrainingActivitySummary({
    required this.activeDays,
    required this.currentStreak,
    required this.completedCount,
  });

  /// 有训练记录的天数
  final int activeDays;

  /// 从 endDate 起向前的连续训练天数
  final int currentStreak;

  /// 91 天窗口内完成训练总次数
  final int completedCount;

  factory TrainingActivitySummary.fromDays(
    List<HeatmapDay> days, {
    required DateTime endDate,
  }) {
    final Map<String, HeatmapDay> byDate = <String, HeatmapDay>{
      for (final HeatmapDay day in days) day.date: day,
    };
    int streak = 0;
    for (int offset = 0; offset < 91; offset++) {
      final DateTime date = DateTime(endDate.year, endDate.month, endDate.day)
          .subtract(Duration(days: offset));
      final HeatmapDay? day = byDate[_isoDate(date)];
      if (day == null || day.completedCount == 0) break;
      streak++;
    }
    return TrainingActivitySummary(
      activeDays: days.where((HeatmapDay day) => day.completedCount > 0).length,
      currentStreak: streak,
      completedCount: days.fold<int>(
        0,
        (int total, HeatmapDay day) => total + day.completedCount,
      ),
    );
  }
}

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 构造对齐到本周周日的 91 天训练窗口
List<HeatmapDay> buildTrainingWindow(
  List<HeatmapDay> source, {
  required DateTime endDate,
}) {
  final DateTime today = DateTime(endDate.year, endDate.month, endDate.day);
  final int daysToSunday = DateTime.sunday - today.weekday;
  final DateTime windowEnd = today.add(Duration(days: daysToSunday));
  final DateTime windowStart = windowEnd.subtract(const Duration(days: 90));
  final Map<String, HeatmapDay> byDate = <String, HeatmapDay>{
    for (final HeatmapDay day in source) day.date: day,
  };

  return List<HeatmapDay>.generate(91, (int index) {
    final DateTime date = windowStart.add(Duration(days: index));
    return byDate[_isoDate(date)] ?? HeatmapDay(date: _isoDate(date), value: 0);
  });
}
