import 'guide_anchor.dart';
import 'guide_controller.dart';
import 'guide_models.dart';

/// 新手指引 · 全部引导内容
///
/// 编排铁律 —— 不满足的一律不写：
/// 1. **只教「看名字看不出来」的**。四个 Tab、点头像改资料、点大卡进功能
///    这类全人类常识全部砍掉；保留的全是隐藏手势和产品特有机制。
/// 2. **按 Tab / 页面分散**，每个入口首次进入只播 1~3 步，绝不一次性灌。
/// 3. **词句克制**：一步只讲一件事，不做功能罗列。
///
/// 当前覆盖面：
///   学生端：开屏速览 3 步 + 训练 1 + 成长 1 + 问诊室 3 + 病历工坊 1
///   教师端：开屏速览 2 步 + 备课 2 + 班级 1 + 备课助手 1 + 作业管理 1
abstract final class GuideTours {
  /// 学生端 Tab id（顺序与底部导航一致）
  static const studentTabIds = ['home', 'training', 'growth', 'profile'];

  /// 教师端 Tab id（顺序与底部导航一致）
  static const teacherTabIds = ['home', 'bprep', 'classes', 'profile'];

  // ==================== 学生端 ====================

  /// 开屏：只讲三条看不见的手势
  static const studentIntro = GuideTour(
    id: 'student_intro',
    intro: true,
    steps: [
      GuideStep(
        title: '向左一滑，唤出问诊助手',
        desc: '问诊室里向左滑屏幕，会滑出「提示 / 思维树 / 引用」托盘，'
            '向右滑收回。',
        gesture: GuideGesture.swipeLeft,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '双指张开，看清每张影像',
        desc: '患者影像与教材配图点开后可双指缩放、单指拖动，'
            '最大放大 8 倍。',
        gesture: GuideGesture.pinch,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '卡片点开，里面还有一层',
        desc: '错题卡点一下会展开 AI 归因；「问 AI」连点则会逐级加大提示力度。',
        gesture: GuideGesture.tap,
        tag: '隐藏操作',
      ),
    ],
  );

  static const studentTraining = GuideTour(
    id: 'student_training',
    steps: [
      GuideStep(
        title: '每日一例：写完有 AI 逐段批改',
        desc: '按九段结构写完提交，AI 会逐段批改并生成能力报告，'
            '这是提分最快的一条路径。',
        anchor: GuideAnchors.studentTrainingDaily,
      ),
    ],
  );

  static const studentGrowth = GuideTour(
    id: 'student_growth',
    steps: [
      GuideStep(
        title: '格子颜色越深，那天练得越久',
        desc: '这张图记录你一整年的学习强度。下方「待复盘」里的错题，'
            '点开会展开 AI 归因。',
        anchor: GuideAnchors.studentGrowthHeatmap,
      ),
    ],
  );

  // ==================== 教师端 ====================

  /// 开屏：教师端最反直觉的两条 —— 长按与拖动
  static const teacherIntro = GuideTour(
    id: 'teacher_intro',
    intro: true,
    steps: [
      GuideStep(
        title: '长按卡片，菜单才出来',
        desc: '备课 / 班级列表里长按任意卡片，才会弹出重命名、置顶、'
            '多选、排序、删除。',
        gesture: GuideGesture.longPress,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '按住右侧手柄，拖动排顺序',
        desc: '进入「排序调整」后拖动卡片改顺序，调完记得点保存。',
        gesture: GuideGesture.drag,
        tag: '隐藏操作',
      ),
    ],
  );

  static const teacherBprep = GuideTour(
    id: 'teacher_bprep',
    steps: [
      GuideStep(
        title: '长按教案卡，管它',
        desc: '重命名、置顶、优先级、多选批量合并、拖动排序都从这里进。',
        anchor: GuideAnchors.teacherBprepCard,
        gesture: GuideGesture.longPress,
      ),
      GuideStep(
        title: '按住麦克风，说话就能输入',
        desc: '备课助手的输入栏与编辑页都有麦克风，按住说、松手自动转文字。',
        gesture: GuideGesture.longPress,
        tag: '隐藏操作',
      ),
    ],
  );

  static const teacherClasses = GuideTour(
    id: 'teacher_classes',
    steps: [
      GuideStep(
        title: '长按班级卡，管到底',
        desc: '邀请成员、成员管理、重命名、多选批量解散、排序都在这里。',
        anchor: GuideAnchors.teacherClassesCard,
        gesture: GuideGesture.longPress,
      ),
    ],
  );

  // ==================== 二级页面（页面级触发） ====================

  /// 学生端 · SP 问诊室：问诊主战场，隐藏交互最密集的一页
  static const studentChat = GuideTour(
    id: 'student_chat',
    steps: [
      GuideStep(
        title: '卡住了？向左滑一下',
        desc: '聊天区向左滑，滑出「提示 / 思维树 / 引用」托盘；'
            '向右滑收回，松手 6 秒也会自动隐藏。',
        anchor: GuideAnchors.studentChatList,
        gesture: GuideGesture.swipeLeft,
        tag: '隐藏操作',
      ),
      GuideStep(
        title: '45 秒没思路，提醒会自己来',
        desc: '超过 45 秒没发消息，屏幕会浮出一条提醒，点一下就能拿到下一步提示。',
        gesture: GuideGesture.tap,
      ),
      GuideStep(
        title: '影像看得不够清楚？双指放大',
        desc: '点开患者影像或教材配图后，双指缩放、单指拖动，最大 6 倍。',
        gesture: GuideGesture.pinch,
        tag: '隐藏操作',
      ),
    ],
  );

  /// 学生端 · 病历工坊：「问 AI」连点升级是最容易被错过、也最救命的机制
  static const studentMr = GuideTour(
    id: 'student_mr',
    steps: [
      GuideStep(
        title: '「问 AI」连续点，提示会升级',
        desc: '第 1 次给追问方向，第 2 次更定向，第 3 次直接示范写法。'
            '写不下去时连点到第 3 级最省时间。',
        anchor: GuideAnchors.studentMrAskAi,
        gesture: GuideGesture.tap,
        tag: '隐藏操作',
      ),
    ],
  );

  /// 教师端 · AI 备课助手：语音输入与课件附件都藏在这一条输入栏里
  static const teacherBprepGuide = GuideTour(
    id: 'teacher_bprep_guide',
    steps: [
      GuideStep(
        title: '按住麦克风说，点附件传',
        desc: '长按麦克风开始说话，松手自动转成文字；'
            '左侧附件支持 PDF / PPT / 视频 / 音频 / 图片，可一次多选。',
        anchor: GuideAnchors.teacherBprepGuideInput,
        gesture: GuideGesture.longPress,
        tag: '隐藏操作',
      ),
    ],
  );

  /// 教师端 · 作业管理：AI 推荐病例 + 底部弹层的关闭方式
  static const teacherAssignment = GuideTour(
    id: 'teacher_assignment',
    steps: [
      GuideStep(
        title: 'AI 推荐病例，一键配齐素材',
        desc: '按这份作业的考点自动匹配病例。弹出的面板可以上下拖动调整高度，'
            '向下拖或点空白处即可收起。',
        anchor: GuideAnchors.teacherAssignmentRecommend,
        gesture: GuideGesture.sheetDrag,
        tag: '隐藏操作',
      ),
    ],
  );

  // ==================== 查询 ====================

  static GuideTour? introOf(GuideRole role) =>
      role == GuideRole.student ? studentIntro : teacherIntro;

  /// 返回 null 表示该 Tab 不需要引导（名称自解释，不打扰）
  static GuideTour? of(GuideRole role, String tabId) => switch (role) {
        GuideRole.student => switch (tabId) {
            'training' => studentTraining,
            'growth' => studentGrowth,
            _ => null,
          },
        GuideRole.teacher => switch (tabId) {
            'bprep' => teacherBprep,
            'classes' => teacherClasses,
            _ => null,
          },
      };

  static String tabIdOf(GuideRole role, int index) {
    final ids = role == GuideRole.student ? studentTabIds : teacherTabIds;
    return ids[index.clamp(0, ids.length - 1)];
  }

  /// 页面级引导：页面 id 与 tour id 相同，见 [GuidePageIds]
  static GuideTour? pageOf(String pageId) => switch (pageId) {
        GuidePageIds.studentChat => studentChat,
        GuidePageIds.studentMr => studentMr,
        GuidePageIds.teacherBprepGuide => teacherBprepGuide,
        GuidePageIds.teacherAssignment => teacherAssignment,
        _ => null,
      };
}

/// 二级页面的引导触发 id（与 tour id 一致，前缀保证 replay 能整组清掉）
abstract final class GuidePageIds {
  static const studentChat = 'student_chat';
  static const studentMr = 'student_mr';
  static const teacherBprepGuide = 'teacher_bprep_guide';
  static const teacherAssignment = 'teacher_assignment';
}
