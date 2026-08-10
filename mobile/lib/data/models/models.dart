// ============================================================
// 数据模型层
// ============================================================

/// 用户角色
enum UserRole {
  student(0),
  teacher(1),
  secretary(2),
  director(3),
  admin(4),
  ops(5);

  const UserRole(this.value);
  final int value;
}

/// 用户模型
class UserModel {
  final int id;
  final String username;
  final String realName;
  final UserRole role;
  final int? classId;
  final int auditStatus; // 0=未提交, 1=待审, 2=通过, 3=驳回
  final int status; // 0=正常, 1=冻结

  // ===== 可编辑个人资料字段 =====
  final String? nickname; // 昵称
  final String? avatarPath; // 头像本地路径
  final String? contact; // 联系方式（手机/邮箱）
  final String? studentNumber; // 学号
  final String? major; // 专业
  final String? grade; // 年级
  final String? password; // 登录密码（本地模拟存储，真实环境应由后端校验）
  final bool needsProfileCompletion; // 新用户注册后是否仍需完善资料
  final bool mustChangePassword; // 后端标记：首次登录或导入后强制改密（来自 LoginResponse/UserInfoVO）

  const UserModel({
    required this.id,
    required this.username,
    required this.realName,
    required this.role,
    this.classId,
    this.auditStatus = 0,
    this.status = 0,
    this.nickname,
    this.avatarPath,
    this.contact,
    this.studentNumber,
    this.major,
    this.grade,
    this.password,
    this.needsProfileCompletion = false,
    this.mustChangePassword = false,
  });

  factory UserModel.mockStudent() => const UserModel(
        id: 1,
        username: '2021302014',
        realName: '陈思远',
        role: UserRole.student,
        classId: 1,
        nickname: '陈思远',
        studentNumber: '2021302014',
        major: '临床医学',
        grade: '大四',
      );

  factory UserModel.mockTeacher() => const UserModel(
        id: 2,
        username: 'wang',
        realName: '王老师',
        role: UserRole.teacher,
        auditStatus: 2,
        nickname: '王老师',
      );

  UserModel copyWith({
    int? id,
    String? username,
    String? realName,
    UserRole? role,
    int? classId,
    int? auditStatus,
    int? status,
    String? nickname,
    String? avatarPath,
    String? contact,
    String? studentNumber,
    String? major,
    String? grade,
    String? password,
    bool? needsProfileCompletion,
    bool? mustChangePassword,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      realName: realName ?? this.realName,
      role: role ?? this.role,
      classId: classId ?? this.classId,
      auditStatus: auditStatus ?? this.auditStatus,
      status: status ?? this.status,
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
      contact: contact ?? this.contact,
      studentNumber: studentNumber ?? this.studentNumber,
      major: major ?? this.major,
      grade: grade ?? this.grade,
      password: password ?? this.password,
      needsProfileCompletion:
          needsProfileCompletion ?? this.needsProfileCompletion,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'realName': realName,
        'role': role.value,
        'classId': classId,
        'auditStatus': auditStatus,
        'status': status,
        'nickname': nickname,
        'avatarPath': avatarPath,
        'contact': contact,
        'studentNumber': studentNumber,
        'major': major,
        'grade': grade,
        'password': password,
        'needsProfileCompletion': needsProfileCompletion,
        'mustChangePassword': mustChangePassword,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        username: json['username'] as String,
        realName: json['realName'] as String,
        role: UserRole.values.firstWhere(
          (e) => e.value == (json['role'] as int),
          orElse: () => UserRole.student,
        ),
        classId: json['classId'] as int?,
        auditStatus: (json['auditStatus'] as int?) ?? 0,
        status: (json['status'] as int?) ?? 0,
        nickname: json['nickname'] as String?,
        avatarPath: json['avatarPath'] as String?,
        contact: json['contact'] as String?,
        studentNumber: json['studentNumber'] as String?,
        major: json['major'] as String?,
        grade: json['grade'] as String?,
        password: json['password'] as String?,
        needsProfileCompletion: (json['needsProfileCompletion'] as bool?) ?? false,
        mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
      );
}

/// 病例难度
enum CaseDifficulty { simple, standard, hard }

/// SP 病例配置
class SpCaseModel {
  final int id;
  final int creatorId;
  final String title;
  final String department;
  final CaseDifficulty difficulty;
  final PatientProfile patientProfile;
  final String hiddenDisease;
  final List<KnowledgeTag> knowledgeTags;
  final List<PresetExam> presetExams;
  final int referenceCount;
  final double ratingAvg;
  final bool isPublic;
  final bool isOfficialCertified;
  final int version;

  const SpCaseModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.department,
    required this.difficulty,
    required this.patientProfile,
    required this.hiddenDisease,
    this.knowledgeTags = const [],
    this.presetExams = const [],
    this.referenceCount = 0,
    this.ratingAvg = 0,
    this.isPublic = false,
    this.isOfficialCertified = false,
    this.version = 1,
  });
}

/// 患者画像
class PatientProfile {
  final int age;
  final String gender;
  final String? occupation;
  final String chiefComplaint;
  final String? presentIllness;
  final String? pastHistory;
  final String? allergyHistory;
  final List<String> personalityTags;

  const PatientProfile({
    required this.age,
    required this.gender,
    this.occupation,
    required this.chiefComplaint,
    this.presentIllness,
    this.pastHistory,
    this.allergyHistory,
    this.personalityTags = const [],
  });
}

/// 知识点标签
class KnowledgeTag {
  final String name;
  const KnowledgeTag(this.name);
}

/// 预设检查项
class PresetExam {
  final String name;
  final double cost;
  final bool isKey;
  final bool canExceed;

  const PresetExam({
    required this.name,
    required this.cost,
    this.isKey = false,
    this.canExceed = false,
  });
}

/// 作业状态
enum AssignmentStatus {
  notStarted(0),
  inProgress(1),
  formatBounced(2),
  aiReviewing(3),
  pendingReview(4),
  completed(5);

  const AssignmentStatus(this.value);
  final int value;
}

/// 作业模型
class AssignmentModel {
  final int id;
  final int teacherId;
  final int caseId;
  final String title;
  final String? description;
  final bool requireMedicalRecord;
  final DateTime? deadline;
  final bool allowLateSubmit;
  final List<String> antiCheatVariables;

  const AssignmentModel({
    required this.id,
    required this.teacherId,
    required this.caseId,
    required this.title,
    this.description,
    this.requireMedicalRecord = true,
    this.deadline,
    this.allowLateSubmit = false,
    this.antiCheatVariables = const [],
  });
}

/// 学生作业实例
class AssignmentInstanceModel {
  final int id;
  final int assignmentId;
  final int studentId;
  final int caseId;
  final String studentName;
  final String studentNumber;
  final String className;
  final AssignmentStatus status;
  final int? aiScore;
  final int? teacherScore;
  final DateTime? submitTime;

  const AssignmentInstanceModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.caseId,
    required this.studentName,
    required this.studentNumber,
    required this.className,
    this.status = AssignmentStatus.notStarted,
    this.aiScore,
    this.teacherScore,
    this.submitTime,
  });
}

/// 消息发送者
enum MessageSender { student, patient, mentor, system }

/// 对话消息
class ChatMessageModel {
  final int id;
  final MessageSender sender;
  final String content;
  final DateTime? timestamp;
  final String? citation;
  final bool isExamResult;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.content,
    this.timestamp,
    this.citation,
    this.isExamResult = false,
  });
}

/// 思维树节点类型
enum TreeNodeType { symptom, history, exam, diagnosis, cost }

/// 思维树节点状态
enum TreeNodeStatus { asked, notAsked, keyMiss, collected, needFollowUp, opened, suggested, overExam, suspected, excluded, lowProbability }

/// 思维树节点
class ThinkingTreeNode {
  final TreeNodeType type;
  final String typeName;
  final TreeNodeStatus status;
  final String statusLabel;
  final String text;
  final String? meta;
  final bool isMiss;
  final bool isWarn;

  const ThinkingTreeNode({
    required this.type,
    required this.typeName,
    required this.status,
    required this.statusLabel,
    required this.text,
    this.meta,
    this.isMiss = false,
    this.isWarn = false,
  });
}

/// OSCE 评分维度
class OsceScore {
  final int historyTaking; // 病史采集
  final int diagnosticLogic; // 诊断逻辑
  final int communication; // 沟通技巧
  final int humanisticCare; // 人文关怀
  final int examDecision; // 检查决策
  final int recordQuality; // 文书规范

  const OsceScore({
    this.historyTaking = 0,
    this.diagnosticLogic = 0,
    this.communication = 0,
    this.humanisticCare = 0,
    this.examDecision = 0,
    this.recordQuality = 0,
  });

  int get total => (historyTaking + diagnosticLogic + communication +
      humanisticCare + examDecision + recordQuality) ~/ 6;
}

/// 错题类型
enum MistakeType { diagnosis, history, exam, record, communication }

/// 错题状态
enum MistakeStatus { unresolved, reviewed, mastered }

/// 错题模型
class MistakeModel {
  final int id;
  final MistakeType type;
  final String typeLabel;
  final String date;
  final String department;
  final String title;
  final String evidence;
  final List<String> tags;
  final MistakeStatus status;

  const MistakeModel({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.date,
    required this.department,
    required this.title,
    required this.evidence,
    this.tags = const [],
    this.status = MistakeStatus.unresolved,
  });
}

/// 病例广场卡片
class CaseMarketItem {
  final int id;
  final String department;
  final String difficulty;
  final String title;
  final String author;
  final String hospital;
  final String grade;
  final String summary;
  final int referenceCount;
  final double rating;
  final int version;
  final bool isOfficial;

  const CaseMarketItem({
    required this.id,
    required this.department,
    required this.difficulty,
    required this.title,
    required this.author,
    required this.hospital,
    required this.grade,
    required this.summary,
    this.referenceCount = 0,
    this.rating = 0,
    this.version = 1,
    this.isOfficial = false,
  });
}

/// 薄弱知识点
class WeaknessPoint {
  final String name;
  final double score;
  const WeaknessPoint(this.name, this.score);
}
