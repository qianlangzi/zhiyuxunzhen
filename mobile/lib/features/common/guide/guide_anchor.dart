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

/// 全 App 使用的锚点常量
abstract final class GuideAnchors {
  /// 底部 Tab 导航胶囊（学生端 / 教师端共用）
  static const bottomBar = 'app.bottom_bar';

  // ---- 学生端 ----
  static const studentHomeCards = 'student.home.cards';
  static const studentTrainingGrid = 'student.training.grid';
  static const studentTrainingDaily = 'student.training.daily';
  static const studentGrowthMistakes = 'student.growth.mistakes';
  static const studentGrowthHeatmap = 'student.growth.heatmap';
  static const studentProfileHero = 'student.profile.hero';

  // ---- 教师端 ----
  static const teacherHomeMarket = 'teacher.home.market';
  static const teacherBprepCreate = 'teacher.bprep.create';
  static const teacherBprepCard = 'teacher.bprep.card';
  static const teacherClassesCreate = 'teacher.classes.create';
  static const teacherClassesCard = 'teacher.classes.card';
  static const teacherProfileHero = 'teacher.profile.hero';
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
