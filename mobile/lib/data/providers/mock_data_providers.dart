import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ============================================================
// Mock 数据 Providers
// ============================================================

/// 学生待办作业列表
final studentAssignmentsProvider = Provider<List<AssignmentModel>>((ref) {
  return [
    AssignmentModel(
      id: 1,
      teacherId: 2,
      caseId: 1,
      title: '心绞痛病例问诊 · 大病历',
      deadline: null,
    ),
    AssignmentModel(
      id: 2,
      teacherId: 3,
      caseId: 2,
      title: '慢阻肺急性加重 · 鉴别诊断',
      deadline: null,
    ),
  ];
});

/// 薄弱知识点列表
final weaknessPointsProvider = Provider<List<WeaknessPoint>>((ref) {
  return const [
    WeaknessPoint('急性冠脉综合征', 0.42),
    WeaknessPoint('肺栓塞鉴别', 0.55),
    WeaknessPoint('慢性心衰分级', 0.61),
    WeaknessPoint('消化道出血', 0.78),
  ];
});

/// 错题本列表
final mistakesProvider = Provider<List<MistakeModel>>((ref) {
  return [
    const MistakeModel(
      id: 1,
      type: MistakeType.diagnosis,
      typeLabel: '诊断错误',
      date: '07.20 · 心血管',
      department: '心血管',
      title: '将急性下壁心梗误诊为胃食管反流',
      evidence: '学生诊断：胃食管反流\n标准诊断：急性下壁+右室心肌梗死\n脱轨节点：未识别上腹痛伴大汗的 ACS 不典型表现',
      tags: ['ACS', '不典型表现', '高危遗漏'],
    ),
    const MistakeModel(
      id: 2,
      type: MistakeType.history,
      typeLabel: '漏问病史',
      date: '07.20 · 心血管',
      department: '心血管',
      title: '未询问胸痛诱因（体力活动/情绪）',
      evidence: '为什么重要：诱因是 ACS 与肺栓塞、主动脉夹层鉴别关键\n对应风险：可能延误再灌注治疗时机',
      tags: ['诱因', '鉴别诊断'],
    ),
    const MistakeModel(
      id: 3,
      type: MistakeType.exam,
      typeLabel: '检查错误',
      date: '07.19 · 呼吸',
      department: '呼吸',
      title: '慢阻肺急性加重病例过度开立 D-二聚体',
      evidence: '学生行为：无 Wells 评估即开 D-二聚体\n建议路径：先评估临床概率，再决定是否查 D-二聚体\n成本超支：¥180 / 单次',
      tags: ['过度检查', '卫生经济学', '慢阻肺'],
    ),
    const MistakeModel(
      id: 4,
      type: MistakeType.record,
      typeLabel: '已掌握',
      date: '07.15 · 消化',
      department: '消化',
      title: '消化道出血未评估出血严重程度',
      evidence: '曾经错误：仅凭主诉判断出血量\n已掌握：已能正确使用 Rockall / Glasgow-Blatchford 评分',
      tags: ['消化道出血', '严重程度评估'],
      status: MistakeStatus.mastered,
    ),
  ];
});

/// 教师待批阅列表
final teacherReviewsProvider = Provider<List<AssignmentInstanceModel>>((ref) {
  return [
    const AssignmentInstanceModel(
      id: 1, assignmentId: 1, studentId: 1, caseId: 1,
      studentName: '陈思远', studentNumber: '2021302014', className: '心血管 03 班',
      status: AssignmentStatus.aiReviewing, aiScore: 82,
    ),
    const AssignmentInstanceModel(
      id: 2, assignmentId: 1, studentId: 2, caseId: 1,
      studentName: '林雨欣', studentNumber: '2021302022', className: '心血管 03 班',
      status: AssignmentStatus.formatBounced,
    ),
    const AssignmentInstanceModel(
      id: 3, assignmentId: 2, studentId: 3, caseId: 2,
      studentName: '赵子轩', studentNumber: '2021302008', className: '呼吸 02 班',
      status: AssignmentStatus.aiReviewing, aiScore: 91,
    ),
    const AssignmentInstanceModel(
      id: 4, assignmentId: 2, studentId: 4, caseId: 2,
      studentName: '周明', studentNumber: '2021302015', className: '呼吸 02 班',
      status: AssignmentStatus.completed, aiScore: 85, teacherScore: 88,
    ),
  ];
});

/// 病例广场列表
final caseMarketProvider = Provider<List<CaseMarketItem>>((ref) {
  return [
    const CaseMarketItem(
      id: 1,
      department: '心血管',
      difficulty: '标准',
      title: '急性下壁心梗的不典型表现',
      author: '王老师',
      hospital: '附属第一医院',
      grade: '大四',
      summary: '58 岁建筑工人，搬运水泥时突发胸痛伴上腹痛，需要学生识别 ACS 不典型表现并完成鉴别诊断。',
      referenceCount: 23,
      rating: 4.8,
      version: 3,
      isOfficial: true,
    ),
    const CaseMarketItem(
      id: 2,
      department: '呼吸',
      difficulty: '困难',
      title: '慢阻肺急性加重伴 II 型呼衰',
      author: '李老师',
      hospital: '附属第二医院',
      grade: '大五/规培',
      summary: '68 岁慢阻肺患者，急性加重伴意识障碍，考察呼吸支持决策和血气分析判读。',
      referenceCount: 15,
      rating: 4.6,
      version: 2,
    ),
    const CaseMarketItem(
      id: 3,
      department: '消化',
      difficulty: '标准',
      title: '肝硬化食管胃底静脉曲张出血',
      author: '张老师',
      hospital: '附属第一医院',
      grade: '大四',
      summary: '52 岁乙肝肝硬化患者呕血 200ml，考察出血量评估、Rockall 评分和急诊处理决策。',
      referenceCount: 31,
      rating: 4.9,
      version: 4,
      isOfficial: true,
    ),
  ];
});

/// OSCE 评分
final osceScoreProvider = Provider<OsceScore>((ref) {
  return const OsceScore(
    historyTaking: 88,
    diagnosticLogic: 85,
    communication: 79,
    humanisticCare: 90,
    examDecision: 76,
    recordQuality: 82,
  );
});
