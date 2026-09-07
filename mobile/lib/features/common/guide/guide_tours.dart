import 'guide_anchor.dart';
import 'guide_controller.dart';
import 'guide_models.dart';

/// 新手指引 · 全部引导内容
///
/// 编排原则（避免耗光用户耐心）：
/// 1. **按 Tab 分散**：每个 Tab 首次进入时才播，一次只 1~3 步，绝不一次性灌 10 步。
/// 2. **先演手势再讲页面**：开屏一条「隐藏手势速览」只讲长按 / 拖动 / 双指这类
///    用户自己永远发现不了的交互；常规的点击入口放到各 Tab 里顺带讲。
/// 3. **只讲高价值**：每页挑 1~2 个最关键、最容易迷路的入口，不做功能罗列。
abstract final class GuideTours {
  /// 学生端 Tab id（顺序与底部导航一致）
  static const studentTabIds = ['home', 'training', 'growth', 'profile'];

  /// 教师端 Tab id（顺序与底部导航一致）
  static const teacherTabIds = ['home', 'bprep', 'classes', 'profile'];

  // ==================== 学生端 ====================

  /// 开屏：学生端隐藏手势速览
  static const studentIntro = GuideTour(
    id: 'student_intro',
    intro: true,
    steps: [
      GuideStep(
        title: '向左一滑，唤出问诊助手',
        desc: '在 SP 问诊室里向左滑动屏幕，会滑出「提示 / 思维树 / 引用」侧边托盘；'
            '向右滑收回，松手 6 秒也会自动隐藏。',
        gesture: GuideGesture.swipeLeft,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '双指张开，看清每张影像',
        desc: '患者影像与教材配图点开后可双指缩放、单指拖动平移，'
            '细节放大到 8 倍，看片子不用再眯眼。',
        gesture: GuideGesture.pinch,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '卡片点开，里面还有一层',
        desc: '错题卡、成长卡片点一下会展开 AI 归因与详情；'
            '病历里的「问 AI」连续点击，提示力度会逐级升级。',
        gesture: GuideGesture.tap,
        tag: '隐藏操作',
      ),
    ],
  );

  static const studentHome = GuideTour(
    id: 'student_home',
    steps: [
      GuideStep(
        title: '四张卡片，直达核心',
        desc: '教材大厅、我的课程、作业待办、加入班级——点卡片直接进入。'
            '作业卡右上角的红点，代表今天还剩几项没做完。',
        anchor: GuideAnchors.studentHomeCards,
      ),
      GuideStep(
        title: '底部四个 Tab',
        desc: '学习 / 训练 / 成长 / 我的。第一次切到某个 Tab 时，'
            '我会自动帮你讲解那一页的关键操作，不会再来第二次。',
        anchor: GuideAnchors.bottomBar,
      ),
    ],
  );

  static const studentTraining = GuideTour(
    id: 'student_training',
    steps: [
      GuideStep(
        title: '四种训练，任选其一开始',
        desc: '病例库练临床思维、基础题库刷考点、模拟试卷做整卷、AI 陪练随时问答。'
            '页面往下拉可以刷新内容。',
        anchor: GuideAnchors.studentTrainingGrid,
      ),
      GuideStep(
        title: '每日一例，一天一道大病历',
        desc: '按九段结构写完提交，AI 会逐段批改并生成能力报告，'
            '写完的病历会自动进入你的病历库。',
        anchor: GuideAnchors.studentTrainingDaily,
      ),
    ],
  );

  static const studentGrowth = GuideTour(
    id: 'student_growth',
    steps: [
      GuideStep(
        title: '颜色越深，那天学得越久',
        desc: '学习热力图记录你一整年的学习强度，点进去可以看到完整的学习档案。',
        anchor: GuideAnchors.studentGrowthHeatmap,
      ),
      GuideStep(
        title: '点开错题，看 AI 归因',
        desc: '下方「待复盘」里每张错题卡点一下，会展开「思维分叉」归因，'
            '告诉你究竟在哪一步想偏了，还能一键生成同类巩固练习。',
        gesture: GuideGesture.tap,
        tag: '隐藏操作',
      ),
    ],
  );

  static const studentProfile = GuideTour(
    id: 'student_profile',
    steps: [
      GuideStep(
        title: '点头像，改资料',
        desc: '资料编辑、学习统计、学习资源入口都在这里。'
            '想再看一遍操作教学，随时点「通用 → 新手指引」。',
        anchor: GuideAnchors.studentProfileHero,
      ),
    ],
  );

  // ==================== 教师端 ====================

  /// 开屏：教师端隐藏手势速览
  static const teacherIntro = GuideTour(
    id: 'teacher_intro',
    intro: true,
    steps: [
      GuideStep(
        title: '长按卡片，唤出管理菜单',
        desc: '在「备课」「班级」列表里长按任意卡片，会弹出重命名、置顶、优先级、'
            '多选、排序、删除——这些按钮平时都是藏起来的。',
        gesture: GuideGesture.longPress,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '按住手柄，拖动排顺序',
        desc: '进入「排序调整」后，按住卡片右侧的手柄上下拖动即可调整顺序，'
            '调完记得点保存。',
        gesture: GuideGesture.drag,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '底部弹层，往下一拖就关',
        desc: '多选面板、AI 推荐、筛选抽屉都是从底部弹出的，'
            '向下拖动或点击空白处即可收起。',
        gesture: GuideGesture.sheetDrag,
        tag: '隐藏操作',
      ),
    ],
  );

  static const teacherHome = GuideTour(
    id: 'teacher_home',
    steps: [
      GuideStep(
        title: 'SP 病例广场，从这里进',
        desc: '浏览、共享、创作标准病例都在广场里；发布 SP 病人也在广场页内，'
            '首页不再单列入口。',
        anchor: GuideAnchors.teacherHomeMarket,
      ),
      GuideStep(
        title: '底部四个 Tab',
        desc: '工作台 / 备课 / 班级 / 我的。作业批阅与班级管理已收进「班级」Tab，'
            '每个 Tab 首次进入都会自动讲一遍。',
        anchor: GuideAnchors.bottomBar,
      ),
    ],
  );

  static const teacherBprep = GuideTour(
    id: 'teacher_bprep',
    steps: [
      GuideStep(
        title: '新建一次备课',
        desc: '点右上角「+ 新建备课」进入 AI 备课助手，按提示逐段生成教案，'
            '再手工打磨成你要的样子。',
        anchor: GuideAnchors.teacherBprepCreate,
      ),
      GuideStep(
        title: '长按教案卡，管理它',
        desc: '长按弹出重命名 / 置顶 / 优先级 / 多选 / 排序 / 删除；'
            '进入多选后可批量智能合并或删除。',
        anchor: GuideAnchors.teacherBprepCard,
        gesture: GuideGesture.longPress,
      ),
      GuideStep(
        title: '长按麦克风，说话就能输入',
        desc: '备课助手的输入栏与编辑页都有麦克风，按住开始说话，'
            '松手自动转成文字，不用手动敲。',
        gesture: GuideGesture.longPress,
        tag: '隐藏操作',
      ),
    ],
  );

  static const teacherClasses = GuideTour(
    id: 'teacher_classes',
    steps: [
      GuideStep(
        title: '建班与发作业',
        desc: '右上角可以「新建班级」或「发放作业」，班级邀请码在班级详情里。',
        anchor: GuideAnchors.teacherClassesCreate,
      ),
      GuideStep(
        title: '长按班级卡，管到底',
        desc: '长按弹出邀请成员、成员管理、重命名、多选（批量解散）、'
            '排序与解散班级。',
        anchor: GuideAnchors.teacherClassesCard,
        gesture: GuideGesture.longPress,
      ),
    ],
  );

  static const teacherProfile = GuideTour(
    id: 'teacher_profile',
    steps: [
      GuideStep(
        title: '点头像，改资料',
        desc: '我的病例、备课、题库、教材都在这一页。'
            '想重看教学，点「通用 → 新手指引」。',
        anchor: GuideAnchors.teacherProfileHero,
      ),
    ],
  );

  // ==================== 查询 ====================

  static GuideTour? introOf(GuideRole role) =>
      role == GuideRole.student ? studentIntro : teacherIntro;

  static GuideTour? of(GuideRole role, String tabId) => switch (role) {
        GuideRole.student => switch (tabId) {
            'home' => studentHome,
            'training' => studentTraining,
            'growth' => studentGrowth,
            'profile' => studentProfile,
            _ => null,
          },
        GuideRole.teacher => switch (tabId) {
            'home' => teacherHome,
            'bprep' => teacherBprep,
            'classes' => teacherClasses,
            'profile' => teacherProfile,
            _ => null,
          },
      };

  static String tabIdOf(GuideRole role, int index) {
    final ids = role == GuideRole.student ? studentTabIds : teacherTabIds;
    return ids[index.clamp(0, ids.length - 1)];
  }
}
