import '../models/assignment_model.dart';
import '../models/case_model.dart';
import '../models/chat_model.dart';
import '../models/learning_model.dart';
import '../models/user_model.dart';
import 'package:zhiyu/data/models.dart';

/// Mock 数据源
/// 对齐 front/legacy-student-teacher/src/views/mockData.ts
/// 后续接入真实接口时，Repository 直接替换为 dio 调用即可
class MockData {
  MockData._();

  static const List<CaseModel> cases = <CaseModel>[
    CaseModel(
      id: 'copd-acute',
      title: '慢阻肺急性加重',
      chief: '反复咳嗽、咳痰 10 年，加重伴气促 3 天',
      tags: <String>['呼吸系统', '低氧血症', '肺功能'],
      department: '呼吸系统',
      difficulty: '进阶',
      duration: '15 分钟',
      referenceCount: 28,
      rating: 4.7,
      certified: true,
    ),
    CaseModel(
      id: 'chest-pain',
      title: '胸痛待查',
      chief: '突发胸骨后压榨样疼痛 2 小时',
      tags: <String>['心血管', '心电图', '鉴别诊断'],
      department: '心血管',
      difficulty: '高阶',
      duration: '18 分钟',
      referenceCount: 43,
      rating: 4.9,
      certified: true,
    ),
    CaseModel(
      id: 'gi-bleeding',
      title: '上消化道出血',
      chief: '黑便 2 天，伴头晕乏力',
      tags: <String>['消化系统', '休克评估', '病史采集'],
      department: '消化系统',
      difficulty: '基础',
      duration: '12 分钟',
      referenceCount: 16,
      rating: 4.4,
      certified: false,
    ),
  ];

  static const List<ChatMessage> chatMessages = <ChatMessage>[
    ChatMessage(by: 'student', text: '您好，我想先确认这次气促是活动后明显，还是安静时也存在？'),
    ChatMessage(by: 'sp', text: '上楼会明显喘，昨晚平躺也觉得憋，需要垫高枕头。'),
    ChatMessage(by: 'mentor', text: '你已经问到端坐呼吸线索，建议继续追问夜间憋醒。'),
  ];

  static const List<ReasoningNode> reasoningNodes = <ReasoningNode>[
    ReasoningNode(label: '气促', type: '症状', state: 'queried'),
    ReasoningNode(label: '端坐呼吸', type: '症状', state: 'active'),
    ReasoningNode(label: '血常规', type: '检查', state: 'done', cost: 35),
    ReasoningNode(label: '心电图', type: '检查', state: 'next', cost: 30),
    ReasoningNode(label: '胸部 CT', type: '检查', state: 'warning', cost: 460),
    ReasoningNode(label: '肺炎', type: '诊断', state: 'excluded'),
    ReasoningNode(label: '心衰', type: '诊断', state: 'next'),
  ];

  static const List<AbilityScore> abilityScores = <AbilityScore>[
    AbilityScore(label: '病史采集', value: 82),
    AbilityScore(label: '诊断逻辑', value: 68),
    AbilityScore(label: '沟通技巧', value: 88),
    AbilityScore(label: '人文关怀', value: 76),
  ];

  static const List<LearningPathItem> learningPath = <LearningPathItem>[
    LearningPathItem(title: '心衰问诊补救病例', meta: '12 分钟 · 简单病例', progress: 35),
    LearningPathItem(title: '胸痛鉴别诊断切片', meta: '教材第 4 章 · 500 字', progress: 64),
    LearningPathItem(title: '血常规判读关卡', meta: '检验指标 · 8 道题', progress: 20),
  ];

  static const List<AssignmentModel> assignments = <AssignmentModel>[
    AssignmentModel(
      title: '内科问诊训练 01',
      className: '临床 2203 班',
      submitted: 37,
      total: 42,
      due: '今晚 22:00',
      status: '进行中',
      requireRecord: true,
      variable: '同病不同检验值',
    ),
    AssignmentModel(
      title: '胸痛鉴别诊断',
      className: '规培一组',
      submitted: 18,
      total: 24,
      due: '明天 18:00',
      status: 'AI 批阅中',
      requireRecord: true,
      variable: '年龄与并发症随机',
    ),
    AssignmentModel(
      title: '消化系统大病历',
      className: '临床 2201 班',
      submitted: 41,
      total: 45,
      due: '周五 12:00',
      status: '待复核',
      requireRecord: true,
      variable: '关闭',
    ),
  ];

  static const List<ReviewItem> reviewQueue = <ReviewItem>[
    ReviewItem(
      id: 1,
      student: '林同学',
      assignment: '胸痛鉴别诊断',
      score: 82,
      issue: '现病史遗漏放射痛方向，未开心电图',
      status: '待复核',
    ),
    ReviewItem(
      id: 2,
      student: '周同学',
      assignment: '慢阻肺急性加重',
      score: 76,
      issue: '体征记录缺少桶状胸和肺部啰音描述',
      status: '已初步批阅',
    ),
    ReviewItem(
      id: 3,
      student: '陈同学',
      assignment: '消化系统大病历',
      score: 89,
      issue: '诊断推理完整，需人工确认用药史',
      status: '有争议项',
    ),
  ];

  static const List<WeaknessItem> weakness = <WeaknessItem>[
    WeaknessItem(tag: '心衰', avg: 0.52, count: 18),
    WeaknessItem(tag: '胸痛鉴别', avg: 0.58, count: 21),
    WeaknessItem(tag: '血常规判读', avg: 0.61, count: 14),
    WeaknessItem(tag: '肺水肿', avg: 0.49, count: 11),
  ];

  static const CaseModel dailyCase = CaseModel(
    id: 'daily-20260627',
    title: '每日一例：活动后胸闷',
    chief: '活动后胸闷',
    tags: <String>['心血管', '心绞痛'],
    department: '心血管',
    difficulty: '进阶',
    duration: '8 分钟',
    referenceCount: 12,
    rating: 4.6,
    certified: true,
    summary: '男，59 岁，活动后胸闷 3 个月，近 1 周加重。既往高血压 8 年。',
    options: <String>['稳定型心绞痛', '支气管哮喘', '急性胃炎', '肺结核'],
    requiredExam: '心电图',
    avoidExam: '无指征胸部增强 CT',
    source: '《内科学》第 3 章，心血管系统，P128',
  );

  static List<HeatmapDay> heatmapDays = List<HeatmapDay>.generate(84, (int index) {
    final int value = (index * 7 + 3) % 5;
    return HeatmapDay(date: 'D-${83 - index}', value: value);
  });

  static const List<MistakeItem> mistakes = <MistakeItem>[
    MistakeItem(
      type: '诊断错误',
      title: '胸痛病例误判为胃炎',
      tag: '胸痛鉴别',
      evidence: '遗漏胸骨后压榨痛、出汗、心电图检查',
      reviewed: false,
    ),
    MistakeItem(
      type: '漏问病史',
      title: '慢阻肺病例未追问夜间憋醒',
      tag: '心衰',
      evidence: '端坐呼吸已经出现，但未继续确认 PND',
      reviewed: true,
    ),
    MistakeItem(
      type: '检查错误',
      title: '优先选择高价 CT',
      tag: '卫生经济学',
      evidence: '未完成低成本必要检查前开立胸部增强 CT',
      reviewed: false,
    ),
  ];

  static const List<FormatShieldRule> formatShieldRules = <FormatShieldRule>[
    FormatShieldRule(label: '主诉 20 字以内', state: '通过', detail: '包含主要症状和持续时间'),
    FormatShieldRule(label: '过敏史不可为空', state: '打回', detail: '未知需填写"否认"或"不详"'),
    FormatShieldRule(label: '现病史时间线', state: '提示', detail: '建议补充症状发展和就诊经过'),
  ];

  static const List<MarketCaseModel> marketCases = <MarketCaseModel>[
    MarketCaseModel(
      title: '胸痛三联鉴别训练',
      author: '心内科教研组',
      department: '心血管',
      difficulty: '高阶',
      referenceCount: 73,
      rating: 4.9,
      certified: true,
    ),
    MarketCaseModel(
      title: '发热伴咳嗽分层问诊',
      author: '呼吸内科教研组',
      department: '呼吸系统',
      difficulty: '进阶',
      referenceCount: 51,
      rating: 4.8,
      certified: true,
    ),
    MarketCaseModel(
      title: '黑便与贫血综合病例',
      author: '消化内科李老师',
      department: '消化系统',
      difficulty: '标准',
      referenceCount: 24,
      rating: 4.5,
      certified: false,
    ),
  ];

  /// 演示账号：对齐 Vue 端 Login.vue
  static const Map<String, _DemoAccount> demoAccounts = <String, _DemoAccount>{
    'teacher01': _DemoAccount(password: '123456', role: 1, displayName: '王老师'),
    'student01': _DemoAccount(password: '123456', role: 0, displayName: '林同学'),
  };

  static UserModel? userFor(String username) {
    final _DemoAccount? acc = demoAccounts[username];
    if (acc == null) return null;
    return UserModel(
      id: username.hashCode,
      username: username,
      displayName: acc.displayName,
      role: acc.role,
      orgName: acc.role == 1 ? '附属一院心内科' : '临床 2203 班',
      credentialStatus: acc.role == 1 ? '已认证' : null,
    );
  }

  static bool verifyDemo(String username, String password) {
    return demoAccounts[username]?.password == password;
  }
}

class _DemoAccount {
  const _DemoAccount({
    required this.password,
    required this.role,
    required this.displayName,
  });

  final String password;
  final int role;
  final String displayName;
}