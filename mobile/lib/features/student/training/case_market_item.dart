/// 病例集市条目模型（对齐后端 CaseMarketListVO），供训练中心 / 病例库页共用。
class CaseMarketItem {
  final int id;
  final String title;
  final String department;
  final String caseNo;
  final int difficulty;
  final double ratingAvg;
  final int referenceCount;
  final String creatorName;
  final String knowledgeTags;
  final String createdAt;

  /// 当前学生最近一次问诊会话ID（未做过为 null）
  final int? lastSessionId;

  /// 当前学生最近一次问诊状态：null未做过 / 0进行中(可继续) / 1已完成(可看报告) / 2评估异常
  final int? lastSessionStatus;

  const CaseMarketItem({
    required this.id,
    required this.title,
    required this.department,
    required this.caseNo,
    required this.difficulty,
    required this.ratingAvg,
    required this.referenceCount,
    required this.creatorName,
    required this.knowledgeTags,
    required this.createdAt,
    this.lastSessionId,
    this.lastSessionStatus,
  });

  /// 学生端对外展示名：科室 + 病号，如「心血管内科 No.213」；不暴露具体病名防剧透。
  String get displayName {
    final dept = department.trim().isEmpty ? '问诊病例' : department.trim();
    final no = caseNo.trim();
    return no.isEmpty ? dept : '$dept · No.$no';
  }

  /// 病号行：No.213 / 未编号时为空串
  String get caseNoLabel {
    final no = caseNo.trim();
    return no.isEmpty ? '' : 'No.$no';
  }

  /// 是否已经做过（进行中/已完成/评估异常都算）
  bool get done => lastSessionStatus != null;

  /// 是否进行中（可继续上次）
  bool get ongoing => lastSessionStatus == 0;

  /// 是否可查看上次报告（已完成/评估异常待重试）
  bool get hasReport =>
      lastSessionStatus == 1 || lastSessionStatus == 2;

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return '简单';
      case 3:
        return '困难';
      case 2:
      default:
        return '标准';
    }
  }

  factory CaseMarketItem.fromJson(Map<String, dynamic> json) {
    return CaseMarketItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '未命名病例',
      department: json['department'] as String? ?? '综合',
      caseNo: json['caseNo'] as String? ?? '',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      referenceCount: (json['referenceCount'] as num?)?.toInt() ?? 0,
      creatorName: json['creatorName'] as String? ?? '',
      knowledgeTags: json['knowledgeTags'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      lastSessionId: (json['lastSessionId'] as num?)?.toInt(),
      lastSessionStatus: (json['lastSessionStatus'] as num?)?.toInt(),
    );
  }
}
