class AssignmentModel {
  final int id;
  final int teacherId;
  final int caseId;
  final String title;
  final String description;
  final bool requireMedicalRecord;
  final DateTime deadline;
  final bool allowLateSubmit;
  final int status; // 0 draft, 1 active, 2 closed
  final int? submitCount;
  final int? totalCount;

  const AssignmentModel({
    required this.id,
    required this.teacherId,
    required this.caseId,
    required this.title,
    required this.description,
    required this.requireMedicalRecord,
    required this.deadline,
    required this.allowLateSubmit,
    required this.status,
    this.submitCount,
    this.totalCount,
  });

  String get statusLabel {
    switch (status) {
      case 0:
        return '草稿';
      case 1:
        return '进行中';
      case 2:
        return '已截止';
      default:
        return '未知';
    }
  }

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] as int,
      teacherId: json['teacher_id'] as int,
      caseId: json['case_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requireMedicalRecord: json['require_medical_record'] as bool? ?? false,
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ??
          DateTime.now(),
      allowLateSubmit: json['allow_late_submit'] as bool? ?? false,
      status: json['status'] as int? ?? 0,
      submitCount: json['submit_count'] as int?,
      totalCount: json['total_count'] as int?,
    );
  }
}
