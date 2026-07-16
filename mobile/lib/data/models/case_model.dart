import 'package:flutter/foundation.dart';

/// 训练病例
@immutable
class CaseModel {
  const CaseModel({
    required this.id,
    required this.title,
    required this.chief,
    required this.tags,
    required this.department,
    required this.difficulty,
    required this.duration,
    required this.referenceCount,
    required this.rating,
    required this.certified,
    this.summary,
    this.options = const <String>[],
    this.requiredExam,
    this.avoidExam,
    this.source,
  });

  final String id;
  final String title;
  final String chief;
  final List<String> tags;
  final String department;

  /// 基础 / 标准 / 进阶 / 高阶
  final String difficulty;
  final String duration;
  final int referenceCount;
  final double rating;
  final bool certified;
  final String? summary;
  final List<String> options;
  final String? requiredExam;
  final String? avoidExam;
  final String? source;
}

/// 病例广场条目
@immutable
class MarketCaseModel {
  const MarketCaseModel({
    required this.title,
    required this.author,
    required this.department,
    required this.difficulty,
    required this.referenceCount,
    required this.rating,
    required this.certified,
  });

  final String title;
  final String author;
  final String department;
  final String difficulty;
  final int referenceCount;
  final double rating;
  final bool certified;
}
