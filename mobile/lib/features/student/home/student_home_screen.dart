import 'dart:async';
import 'dart:ui'; // ImageFilter（底部毛玻璃浮层）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/common/guide/guide_anchor.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 学生端首页 · 学习中心（校园风设计规范 · Flutter 版）
///
/// 依据「医学生校园 APP 首页 - 设计规范」实现：
/// 三层背景（全屏校园背景 + 渐变遮罩 + 底部弧形浮层）→ 顶部文字区（动态时间/日期/问候）
/// → 四张矮卡片（人物全高站立、左右交替朝向，完整落地不越界）。
/// 昼夜切换按【系统时间】自动触发（18:00~次日 6:00 为夜晚，替换夜间素材），与手机深色模式无关。
class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  Map<String, dynamic>? _assignmentsData;
  /// 资料任务待办数（教师发布 materialOnly=1 的备课资料，未标记完成的）
  int _lessonTodoCount = 0;
  bool _isLoadingAssignments = true;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // 时间自动检测：每分钟刷新时钟/日期/问候语，不写死
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssignments());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    // 并行拉取：作业待办 + 资料任务（与待办页同口径）
    final results = await Future.wait<Object?>([
      StudentService().getTodoAssignments(),
      StudentService().getStudentTasks(),
    ]);
    if (mounted) {
      final tasks = results[1] as List<dynamic>?;
      final lessonTodo = tasks
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .where((m) =>
                  (m['materialOnly'] as num?)?.toInt() == 1 &&
                  m['completed'] != true)
              .length ??
          0;
      setState(() {
        _assignmentsData = results[0] as Map<String, dynamic>?;
        _lessonTodoCount = lessonTodo;
        _isLoadingAssignments = false;
      });
    }
  }

  /// 仅刷新待办作业（任务完成后使角标/描述实时消失）
  Future<void> _refreshAssignments() async {
    await _loadAssignments();
  }

  int get _todoCount {
    if (_isLoadingAssignments) return 0;
    return (_assignmentsData?['total'] as int? ?? 0);
  }

  /// 「我的课程」侧待办总数 = 作业待办 + 资料任务待办（与待办页顶部汇总一致）
  int get _coursePendingCount => _todoCount + _lessonTodoCount;

  /// 进入深页后返回首页时刷新待办，保证「任务完成 → 待办消失」。
  Future<void> _pushThenRefresh(Future<void> Function() nav) async {
    await nav();
    _refreshAssignments();
  }

  /// 打开「我的课程」独立页（学习通式课程卡列表）。
  Future<void> _openMyCourses() async {
    context.pushNamed(RouteNames.myCourses);
  }

  // ---------------- 顶部动态文字 ----------------
  // 顶部时间交还给系统状态栏（左上角时间不再显示，避免和手机任务栏重复）

  String get _dateText =>
      '今天是星期${['一', '二', '三', '四', '五', '六', '日'][_now.weekday - 1]}';

  String _greetingText(String name) {
    final hour = _now.hour;
    if (hour >= 5 && hour < 12) return '嗨，$name！';
    if (hour >= 12 && hour < 18) return '下午好，$name！';
    return '晚上好，$name！';
  }

  /// 昼夜判断：**完全跟随全 App 主题**，首页不再自行判断时间。
  ///
  /// 时间调度已上移到 [ZhiyuApp]（设置项 浅色/深色/自动，「自动」在
  /// 18:00~次日 6:00 把整个 App 切到 darkPalette）。首页只需读主题亮度，
  /// 即可保证「首页夜景 ⟺ 全 App 深色」永远一致。
  ///
  /// 历史坑（勿回退）：
  /// 1. 只看时间、忽略主题 → 系统深色模式下白天打开，首页亮色、其余页深色。
  /// 2. 「主题 dark **或** 时间在夜间」→ 用户明确选了浅色，凌晨打开时首页
  ///    仍切夜景，而二级页是米白底深墨字，割裂更严重。
  /// 正确做法是让首页成为主题的**跟随者**，而不是自己另算一套。
  bool _nightOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ---------------- 夜间分层色板（不依赖 lightPalette） ----------------
  //
  // 夜间采用「分层柔性遮罩」而非一刀切的强渐变，三层各司其职：
  //   1. 全屏薄 veil  —— 统一压暗，让校园夜景插画全屏透出（不切掉下半截）
  //   2. 色温统一层   —— 靛蓝淡染，消除「冷蓝夜空 + 月光绿草坪」的拼接感
  //   3. 顶部局部加深 —— 只在文字区从 55% 渐隐到 0，给白字一个稳定暗衬底
  //
  // 关键认知：Flutter Stack 里文字画在遮罩**之上**，所以遮罩淡化不会让字变虚，
  // 遮罩决定的是「字背后的底色干不干净」。局部加深就是为了保证这块底色稳定，
  // 背后是月亮还是暗空都不影响可读性。

  /// 1 · 全屏薄 veil：夜间整屏压暗，但插画仍全屏可见
  static const Color _nightVeil = Color(0xFF0A0F1A);

  /// 全屏 veil 强度（越低插画越清楚，越高字越稳）
  static const double _nightVeilAlpha = 0.32;

  /// 2 · 色温统一层：靛蓝淡染，把冷蓝夜空与月光绿草坪揉成同一张画
  static const Color _nightTint = Color(0xFF1A2740);

  /// 色温层强度（过大会发蓝，控制在 0.15 以内）
  static const double _nightTintAlpha = 0.13;

  /// 3 · 顶部文字区局部加深（scrim），从文字区顶端渐隐到透明
  static const Color _nightScrim = Color(0xFF080C16);

  /// 局部加深的起始 alpha（文字区顶端）
  static const double _nightScrimAlpha = 0.55;

  /// 4 · 底部浮层（毛玻璃）底色，与卡片底部文字块同色
  static const Color _nightSurface = Color(0xFF14191E);

  /// 毛玻璃浮层不透明度（越低越透出校园夜景，越高卡片越实）
  static const double _nightGlassAlpha = 0.66;

  /// 毛玻璃模糊半径
  static const double _nightGlassBlur = 18.0;

  /// 顶部文字：夜间用白色系。有局部加深兜底，对比度稳
  Color get _nightTextStrong =>
      Colors.white.withValues(alpha: 0.96); // 问候语：32px 接近纯白
  Color get _nightTextSoft =>
      Colors.white.withValues(alpha: 0.82); // 副标题/日期

  @override
  Widget build(BuildContext context) {
    final isNight = _nightOf(context);
    final user = ref.watch(authProvider).user;
    final name = user?.nickname ?? user?.realName ?? 'mxz';
    // 夜间分支：不论系统主题，强制走「分层柔性遮罩」色板，与 lightPalette 解耦。
    // 背景图 BoxFit.cover 铺满全屏，bg 仅作兜底（被图完全盖住，看不见）。
    final bg = isNight ? _nightSurface : AppColors.bgOf(context);
    final surface = isNight ? _nightSurface : AppColors.surfaceOf(context);
    // 顶部文字：夜间用白色系，保证在夜空图上可读
    final textStrong =
        isNight ? _nightTextStrong : AppColors.textOf(context);
    final textSoft = isNight ? _nightTextSoft : AppColors.text3Of(context);

    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final safeTop = MediaQuery.paddingOf(context).top;
          // 矮屏压缩：卡片/人物略缩，保证四张卡片不被顶部副标题压到
          final compact = h < 720;
          // 更矮更宽的卡片：人物完整落在卡片内、不越界
          final cardH = compact ? 200.0 : 236.0;
          final charH = compact ? 104.0 : 116.0; // 全身小人（含腿脚与气球）等比缩放
          final charBottom = compact ? 76.0 : 78.0; // 脚部落在卡片内、贴近底部，不外溢
          final cardsBottom = compact ? 12.0 : 16.0; // 卡片底距底部导航的间距

          return Stack(
            fit: StackFit.expand,
            children: [
              // Layer 0 —— 全屏校园背景（按系统时间切换夜晚素材）
              Image.asset(
                isNight
                    ? 'assets/images/campus_bg_night.png'
                    : 'assets/images/campus_bg.png',
                fit: BoxFit.cover,
              ),
              // Layer 1 —— 全屏薄 veil（夜间）/ 渐变遮罩（白天）
              //
              // 夜间：整屏均匀压暗 32%，校园夜景插画从顶到底全屏透出，
              //       不再像旧版那样把插画下半截切掉、留一块纯色。
              // 白天：沿用原渐变（透明 → 纸色），视觉不变。
              if (isNight)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _nightVeil.withValues(alpha: _nightVeilAlpha),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.55, 0.70, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        bg.withValues(alpha: 0.5),
                        bg.withValues(alpha: 0.95),
                        bg,
                      ],
                    ),
                  ),
                ),

              // Layer 1.5 —— 色温统一层（仅夜间）
              // 夜空是冷蓝、月光草坪偏绿，两者色温不同，压暗后仍有"拼接感"。
              // 叠一层极淡靛蓝把上下揉成同一张画（控制在 13%，过大会发蓝）。
              if (isNight)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _nightTint.withValues(alpha: _nightTintAlpha),
                  ),
                ),

              // Layer 1.6 —— 顶部文字区局部加深 scrim（仅夜间）
              // 只盖文字那一块（从顶部到 safeTop+190），从 55% 渐隐到 0。
              // 作用：给白字一个稳定的暗衬底，背后是月亮还是暗空都不影响可读性。
              // 下方完全不加深，插画保持通透。
              if (isNight)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: safeTop + 190,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 0.78, 1.0],
                        colors: [
                          _nightScrim.withValues(alpha: _nightScrimAlpha),
                          _nightScrim.withValues(alpha: _nightScrimAlpha * 0.76),
                          _nightScrim.withValues(alpha: _nightScrimAlpha * 0.25),
                          _nightScrim.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

              // Layer 2 —— 底部弧形浮层
              // 夜间：毛玻璃（模糊下层校园夜景 + 半透明深炭），
              //       透出底下模糊的校舍轮廓，比不透明纯色块更有层次。
              //       卡片本身是实色的，所以卡片上的字不受模糊影响。
              // 白天：沿用原半透明纸色浮层。
              Positioned(
                top: h - cardH - cardsBottom - 44,
                left: 0,
                right: 0,
                bottom: 0,
                child: isNight
                    ? _buildNightGlassSheet(surface)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: surface.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(40),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 32,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                      ),
              ),

              // ---- 顶部文字区：日期 / 问候语 / 副标题（时间交还系统状态栏，不再显示） ----
              Positioned(
                top: safeTop + (compact ? 12 : 14),
                left: 24,
                child: Text(
                  _dateText,
                  style: TextStyle(
                    fontSize: 15,
                    color: textSoft,
                  ),
                ),
              ),
              Positioned(
                top: safeTop + (compact ? 44 : 52),
                left: 24,
                child: Text(
                  _greetingText(name),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: textStrong,
                  ),
                ),
              ),
              Positioned(
                top: safeTop + (compact ? 80 : 96),
                left: 24,
                child: Text(
                  '带着一点好奇心，开始今天的学习吧',
                  style: TextStyle(
                    fontSize: 15,
                    color: textSoft,
                  ),
                ),
              ),

              // ---- 功能卡片区（紧贴底部导航上方） ----
              // 套 GuideTarget：新手指引会高亮这一排卡片
              Positioned(
                left: 16,
                right: 16,
                bottom: cardsBottom,
                child: GuideTarget(
                  anchor: GuideAnchors.studentHomeCards,
                  child: _buildCards(
                    cardH: cardH,
                    charH: charH,
                    charBottom: charBottom,
                    isNight: isNight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- 夜间毛玻璃浮层 ----------------

  /// 夜间底部浮层：毛玻璃（frosted glass）
  ///
  /// [BackdropFilter] 会对**下层**已绘制内容（校园夜景插画 + veil + 色温层）
  /// 做高斯模糊，于是卡片区能透出底下模糊的校舍轮廓，比不透明纯色块更有层次。
  /// 卡片本身是实色的，所以卡片上的标题/描述完全不受模糊影响。
  ///
  /// 两个坑：
  /// 1. 阴影必须放在 [ClipRRect] **之外**，否则会被圆角裁掉。
  /// 2. 必须 [ClipRRect] 包 [BackdropFilter]，否则模糊会溢出到整屏。
  ///
  /// 性能：本页是静态页（无滚动），模糊区域约 300px 高，开销可接受。
  Widget _buildNightGlassSheet(Color surface) {
    const radius = BorderRadius.vertical(top: Radius.circular(40));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _nightGlassBlur,
            sigmaY: _nightGlassBlur,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface.withValues(alpha: _nightGlassAlpha),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 功能卡片区 ----------------
  Widget _buildCards({
    required double cardH,
    required double charH,
    required double charBottom,
    required bool isNight,
  }) {
    final grads = _cardGradients(isNight);
    final cards = <_CardData>[
      _CardData(
        title: '教材大厅',
        desc: '查教材',
        asset: 'assets/images/student_textbook.png',
        shift: -0.06, // 朝左 · 身体偏右 → 左移对准卡片中心
        onTap: () => context.pushNamed(RouteNames.textbookCenter),
      ),
      _CardData(
        title: '我的课程',
        desc: _coursePendingCount > 0 ? '$_coursePendingCount 项待办' : '暂无待办',
        asset: 'assets/images/student_course.png',
        shift: 0.08, // 朝右 · 身体偏左 → 右移对准卡片中心
        badge: _coursePendingCount,
        onTap: () => _pushThenRefresh(_openMyCourses),
      ),
      _CardData(
        title: '作业待办',
        desc: _todoCount > 0 ? '$_todoCount 项待完成' : '今日无待办',
        asset: 'assets/images/student_assignment.png',
        shift: -0.10,
        badge: _todoCount,
        onTap: () => _pushThenRefresh(
          () => context.pushNamed(RouteNames.todoAssignments),
        ),
      ),
      _CardData(
        title: '加入班级',
        desc: '输入邀请码',
        asset: 'assets/images/student_class.png',
        shift: 0.08,
        onTap: () => context.pushNamed(RouteNames.studentJoinClass),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildCard(
              cards[i],
              gradient: grads[i],
              cardH: cardH,
              charH: charH,
              charBottom: charBottom,
              isNight: isNight,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(
    _CardData d, {
    required List<Color> gradient,
    required double cardH,
    required double charH,
    required double charBottom,
    required bool isNight,
  }) {
    final charW = charH * 0.75; // 素材统一 3:4，人物显示宽度 = 高度 × 0.75
    // 夜间卡片底色是不透明深炭灰（0xFF14191E），文字必须白色系才能读。
    // 否则取 lightPalette 的深墨字会糊在暗卡上、看不见。
    final titleColor = isNight ? Colors.white : AppColors.textOf(context);
    final descColor =
        isNight ? Colors.white.withValues(alpha: 0.65) : AppColors.text2Of(context);

    return AppPressable(
      onTap: d.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: cardH,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000), // rgba(0,0,0,0.1)
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0x0F000000), // rgba(0,0,0,0.06)
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          // 人物全高落入卡片内部（charBottom>0），不外溢
          clipBehavior: Clip.hardEdge,
          children: [
            // 微信式红点角标：课程右上角显示待办数
            if (d.badge > 0)
              Positioned(
                top: 10,
                right: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5484D).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      d.badge > 99 ? '99+' : '${d.badge}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            // 人物：全高站立，脚部落在卡片内，气球随材质等比缩小
            Positioned(
              left: 0,
              right: 0,
              bottom: charBottom,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(charW * d.shift, 0),
                    child: Image.asset(
                      d.asset,
                      height: charH,
                      width: charW,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // 底部文字（标题 + 描述）
            // 夜间版改为不透明深色底色：避免「半透 + 暗卡 + 暗背景」三层叠在一起糊成一片，
            // 标题/描述文字必须落在稳定的色块上才能保证可读。
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0xFF14191E)
                      : AppColors.surfaceOf(context).withValues(alpha: 0.82),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: descColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 四张卡片的渐变配色（白天 / 夜晚）
  ///
  /// 夜晚版策略：
  /// - 4 张卡全部用炭灰会与夜空背景"融成一片"，把人物抠出来都费劲。
  /// - 改为「低饱和品牌色相」深色卡：保留夜间氛围，但每张卡都有色相区分，
  ///   卡片边界 / 人物 / 文字都可读，整体不再黑乎乎。
  /// - 顺序与人物手里的物品色相呼应：绿皮书 → 蓝气球书 → 橙作业夹 → 粉爱心。
  List<List<Color>> _cardGradients(bool isNight) => isNight
      ? const [
          [Color(0xFF2D4A3E), Color(0xFF1B2C25)], // 教材大厅 - 苔藓深绿
          [Color(0xFF3A4A6E), Color(0xFF222A40)], // 我的课程 - 靛青
          [Color(0xFF8A6A2E), Color(0xFF4F3D1A)], // 作业待办 - 琥珀
          [Color(0xFF8A3A5A), Color(0xFF4F2438)], // 加入班级 - 玫红
        ]
      : const [
          [Color(0xFFFFFDF5), Color(0xFFFFF8E1)],
          [Color(0xFFF0F8FF), Color(0xFFE3F2FD)],
          [Color(0xFFFFF8F0), Color(0xFFFFECB3)],
          [Color(0xFFFFF0F5), Color(0xFFFCE4EC)],
        ];
}

/// 单张功能卡片数据
class _CardData {
  const _CardData({
    required this.title,
    required this.desc,
    required this.asset,
    required this.shift,
    required this.onTap,
    this.badge = 0,
  });

  final String title;
  final String desc;
  final String asset;
  final double shift; // 人物水平偏移（占图片宽度比例），实现左右交错
  final VoidCallback onTap;

  /// 徽标数字（>0 时在卡片右上角显示，作业待办待办数用）
  final int badge;
}
