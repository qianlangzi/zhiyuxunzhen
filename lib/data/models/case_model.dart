class CaseModel {
  final int id;
  final String title;
  final String department;
  final int difficulty; // 1 easy, 2 standard, 3 hard
  final String chiefComplaint;
  final String? hiddenDisease;
  final List<String> knowledgeTags;
  final bool isPublic;
  final int referenceCount;
  final double ratingAvg;
  final int adminAuditStatus;
  final int version;
  final int status;

  const CaseModel({
    required this.id,
    required this.title,
    required this.department,
    required this.difficulty,
    required this.chiefComplaint,
    this.hiddenDisease,
    required this.knowledgeTags,
    required this.isPublic,
    required this.referenceCount,
    required this.ratingAvg,
    required this.adminAuditStatus,
    required this.version,
    required this.status,
  });

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return '简单';
      case 2:
        return '标准';
      case 3:
        return '困难';
      default:
        return '未知';
    }
  }

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      department: json['department'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 2,
      chiefComplaint: json['chief_complaint'] as String? ?? '',
      hiddenDisease: json['hidden_disease'] as String?,
      knowledgeTags: (json['knowledge_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPublic: json['is_public'] as bool? ?? false,
      referenceCount: json['reference_count'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      adminAuditStatus: json['admin_audit_status'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
      status: json['status'] as int? ?? 0,
    );
  }
}
