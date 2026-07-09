import 'package:flutter/foundation.dart';

/// 问诊消息
@immutable
class ChatMessage {
  const ChatMessage({
    required this.by,
    required this.text,
    this.timestamp,
  });

  /// student / sp / mentor
  final String by;
  final String text;
  final DateTime? timestamp;

  String get speaker {
    switch (by) {
      case 'student':
        return '学生';
      case 'sp':
        return '模拟病人';
      case 'mentor':
        return '智能导师';
      default:
        return by;
    }
  }
}

/// 思维路径节点
@immutable
class ReasoningNode {
  const ReasoningNode({
    required this.label,
    required this.type,
    required this.state,
    this.cost,
  });

  final String label;
  /// 症状 / 检查 / 诊断
  final String type;
  /// queried / active / done / next / warning / excluded
  final String state;
  final int? cost;
}