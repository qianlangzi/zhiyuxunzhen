import 'package:flutter/foundation.dart';

/// 教师下发的训练任务
@immutable
class AssignmentModel {
  const AssignmentModel({
    required this.title,
    required this.className,
    required this.submitted,
    required this.total,
    required this.due,
    required this.status,
    required this.requireRecord,
    required this.variable,
  });

  final String title;
  final String className;
  final int submitted;
  final int total;
  final String due;
  final String status;
  final bool requireRecord;
  /// 同病不同检验值 / 关闭 等
  final String variable;

  double get progress => total == 0 ? 0 : submitted / total;
}

/// 批阅队列条目
@immutable
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.student,
    required this.assignment,
    required this.score,
    required this.issue,
    required this.status,
  });

  final int id;
  final String student;
  final String assignment;
  final int score;
  final String issue;
  /// 待复核 / 已初步批阅 / 有争议项 / 已复核
  final String status;
}

/// 格式盾牌校验规则
@immutable
class FormatShieldRule {
  const FormatShieldRule({
    required this.label,
    required this.state,
    required this.detail,
  });

  final String label;
  /// 通过 / 打回 / 提示
  final String state;
  final String detail;
}

/// 班级薄弱点
@immutable
class WeaknessItem {
  const WeaknessItem({
    required this.tag,
    required this.avg,
    required this.count,
  });

  final String tag;
  final double avg;
  final int count;
}