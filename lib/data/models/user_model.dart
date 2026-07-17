class UserModel {
  final int id;
  final String username;
  final String realName;
  final int role; // 0 student, 1 teacher
  final int? classId;
  final int auditStatus; // 0 not submitted, 1 pending, 2 passed, 3 rejected
  final int status; // 0 normal, 1 frozen
  final String token;

  const UserModel({
    required this.id,
    required this.username,
    required this.realName,
    required this.role,
    this.classId,
    required this.auditStatus,
    required this.status,
    required this.token,
  });

  bool get isStudent => role == 0;
  bool get isTeacher => role == 1;
  bool get isAuditPassed => auditStatus == 2;

  factory UserModel.fromJson(Map<String, dynamic> json, String token) {
    return UserModel(
      id: json['user_id'] as int,
      username: json['username'] as String,
      realName: json['real_name'] as String? ?? '',
      role: json['role'] as int,
      classId: json['class_id'] as int?,
      auditStatus: json['audit_status'] as int? ?? 0,
      status: json['status'] as int? ?? 0,
      token: token,
    );
  }
}
