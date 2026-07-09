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
  });

  final String date;
  /// 0~4
  final int value;
}