import 'package:flutter/material.dart';

/// 引导锚点注册表
///
/// 页面里用 [GuideTarget] 包住要教学的控件，控件会把自己的 [GlobalKey]
/// 注册进来；引导层每帧通过 [rectOf] 取它在屏幕上的位置来「挖洞」。
///
/// 每帧测量的好处：页面滚动、列表懒加载、Tab 切换动画过程中，
/// 高亮光圈都会平滑跟随，不会出现「洞飘在半空」的尴尬。
abstract final class GuideAnchorRegistry {
  static final Map<String, GlobalKey> _keys = {};

  static void register(String anchor, GlobalKey key) => _keys[anchor] = key;

  static void unregister(String anchor, GlobalKey key) {
    if (_keys[anchor] == key) _keys.remove(anchor);
  }

  /// 取锚点在屏幕坐标系中的矩形；未注册 / 未挂载 / 未布局时返回 null
  static Rect? rectOf(String? anchor) {
    if (anchor == null) return null;
    final ctx = _keys[anchor]?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final obj = ctx.findRenderObject();
    if (obj is! RenderBox || !obj.hasSize || !obj.attached) return null;
    return obj.localToGlobal(Offset.zero) & obj.size;
  }
}

/// 引导锚点常量
///
/// 只保留「看名字理解不了」的目标：一个页面最多 1 个锚点，
/// 绝不给常识性入口（Tab 栏、头像卡、标题大卡）挂引导。
abstract final class GuideAnchors {
  // ---- 学生端 ----
  /// 训练 Tab · 每日一例卡（背后有 AI 逐段批改，看名字看不出来）
  static const studentTrainingDaily = 'student.training.daily';

  /// 成长 Tab · 学习热力图（颜色深浅的含义不自解释）
  static const studentGrowthHeatmap = 'student.growth.heatmap';

  // ---- 教师端 ----
  /// 备课 Tab · 首张教案卡（长按才出管理菜单）
  static const teacherBprepCard = 'teacher.bprep.card';

  /// 班级 Tab · 首张班级卡（长按才出管理菜单）
  static const teacherClassesCard = 'teacher.classes.card';

  // ---- 二级页面 ----
  /// SP 问诊室 · 聊天区（左滑唤出托盘的判定区域）
  static const studentChatList = 'student.chat.list';

  /// 病历工坊 · 首段「问 AI」按钮（连点升级机制）
  static const studentMrAskAi = 'student.mr.askAi';

  /// AI 备课助手 · 底部输入栏（长按麦克风 / 附件上传）
  static const teacherBprepGuideInput = 'teacher.bprepGuide.input';

  /// 作业管理 · AI 推荐按钮（弹出可拖拽关闭的病例面板）
  static const teacherAssignmentRecommend = 'teacher.assignment.recommend';
}

/// 把子控件标记为引导高亮目标
///
/// 零成本：只是在子控件外面套一个带 [GlobalKey] 的 [KeyedSubtree]，
/// 不影响布局与点击。
class GuideTarget extends StatefulWidget {
  const GuideTarget({
    super.key,
    required this.anchor,
    required this.child,
    this.circle = false,
  });

  /// 锚点名，取自 [GuideAnchors]
  final String anchor;

  final Widget child;

  /// 高亮形状：true 为圆形，false 为圆角矩形
  final bool circle;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    GuideAnchorRegistry.register(widget.anchor, _key);
  }

  @override
  void didUpdateWidget(covariant GuideTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor != widget.anchor) {
      GuideAnchorRegistry.unregister(oldWidget.anchor, _key);
      GuideAnchorRegistry.register(widget.anchor, _key);
    }
  }

  @override
  void dispose() {
    GuideAnchorRegistry.unregister(widget.anchor, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
