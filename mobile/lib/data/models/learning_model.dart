import 'package:flutter/foundation.dart';

/// OSCE 四维能力
@immutable
class AbilityScore {
  const AbilityScore({
    required this.label,
    required this.value,
  });

  final String label;

  /// 0~100
  final int value;
}

/// 学习路径条目
@immutable
class LearningPathItem {
  const LearningPathItem({
    required this.title,
    required this.meta,
    required this.progress,
  });

  final String title;
  final String meta;

  /// 0~100
  final int progress;
}

/// 错题
@immutable
class MistakeItem {
  const MistakeItem({
    required this.type,
    required this.title,
    required this.tag,
    required this.evidence,
    required this.reviewed,
  });

  final String type;
  final String title;
  final String tag;
  final String evidence;
  final bool reviewed;
}

/// 学习热力图每日数据
@immutable
class HeatmapDay {
  const HeatmapDay({
    required this.date,
    required this.value,
    this.completedCount = 0,
    this.activities = const <String>[],
  });

  final String date;

  /// 0~4 视觉强度
  final int value;

  /// 当日完成训练次数
  final int completedCount;

  /// 当日活动标签（最多两条简短中文）
  final List<String> activities;

  DateTime get parsedDate => DateTime.parse(date);
}
