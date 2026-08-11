import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/models.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../student/data/student_service.dart';

/// 学生端首页 · 学习中心
class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  Map<String, dynamic>? _dailyCaseData;
  Map<String, dynamic>? _assignmentsData;
  Map<String, dynamic>? _overviewData;
  Map<String, dynamic>? _questionStats;
  bool _isLoadingAssignments = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final service = StudentService();
    final dailyCase = await service.getTodayDailyCase();
    final assignments = await service.getMyAssignments();
    final overview = await service.getReportOverview();
    final stats = await service.getQuestionStats();
    if (mounted) {
      setState(() {
        _dailyCaseData = dailyCase;
        _assignmentsData = assignments;
        _overviewData = overview;
        _questionStats = stats;
        _isLoadingAssignments = false;
      });
    }
  }

  Future<void> _openGlobalSearch() async {
    final keyword = await showDialog<String>(
      context: context,
      builder: (ctx) => const _HomeSearchDialog(),
    );
    if (keyword != null && keyword.trim().isNotEmpty) {
      context.pushNamed(
        RouteNames.searchResult,
        queryParameters: {'keyword': keyword.trim()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // AppBar
            const AppTitleAppBar(
              tag: '内科教研 · 学生端',
              title: '学习中心',
              action: AppIconButton(
                icon: Icon(Icons.notifications_outlined, size: 20),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(user),
                    const SizedBox(height: 20),
                    _buildHeatmap(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildEntryGrid(),
                    const MedicalDisclaimer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 问候区
  Widget _buildGreeting(UserModel? user) {
    final displayName = user?.nickname ?? user?.realName ?? '同学';
    final major = user?.major ?? '临床医学';
    final grade = user?.grade ?? '大四';
    final subtitle = '$major · $grade · 内科学';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.textOf(context),
                height: 1.1,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 4),
            MonoText(
              subtitle,
              fontSize: 12,
              color: AppColors.text3Of(context),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '23',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOf(context),
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '连续训练天数',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.text3Of(context),
                fontFamily: 'JetBrainsMono',
                letterSpacing: 0.08,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 学习热力图
  Widget _buildHeatmap() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '学习热力',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              Row(
                children: [
                  const MonoText('近一年 · 完成 ', fontSize: 11),
                  Text(
                    '142',
                    style: TextStyle(
                      color: AppColors.primaryOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  const MonoText(' 次训练', fontSize: 11),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HeatmapGrid(
            activityDays: _overviewData?['activityDays'] as List<dynamic>?,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const MonoText('少', fontSize: 10),
              const SizedBox(width: 6),
              Row(
                children: [
                  _heatCell(AppColors.paper2Of(context)),
                  const SizedBox(width: 3),
                  _heatCell(AppColors.heatL1),
                  const SizedBox(width: 3),
                  _heatCell(AppColors.heatL2),
                  const SizedBox(width: 3),
                  _heatCell(AppColors.heatL3),
                  const SizedBox(width: 3),
                  _heatCell(AppColors.heatL4),
                ],
              ),
              const SizedBox(width: 6),
              const MonoText('多', fontSize: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heatCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // 智能检索入口
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _openGlobalSearch,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.manage_search, size: 18, color: AppColors.primaryOf(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '智能检索 · 教材 / 基础题 / 病例',
                style: TextStyle(fontSize: 13, color: AppColors.text4Of(context)),
              ),
            ),
            MonoText('SEARCH', fontSize: 10, color: AppColors.text4Of(context)),
          ],
        ),
      ),
    );
  }

  // 四块功能入口（bento 网格：同一水平两个、大小与配色各不相同）
  Widget _buildEntryGrid() {
    return Column(
      children: [
        // 第一行：教材中心（较窄，靛蓝）+ 每日一例（较宽，主色）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _textbookBlock()),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _dailyCaseBlock()),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：待办作业（较宽，琥珀）+ 基础题训练（较窄，苔藓绿）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: _todoBlock()),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _trainingBlock()),
          ],
        ),
      ],
    );
  }

  Widget _blockShell({
    required Color bg,
    required VoidCallback onTap,
    required Widget child,
    double? height,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      ),
    );
  }

  // 教材中心（靛蓝）
  Widget _textbookBlock() {
    return _blockShell(
      bg: AppColors.indigoSoftOf(context),
      height: 150,
      onTap: () => context.pushNamed(RouteNames.textbookCenter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(AppColors.indigo, Icons.menu_book_rounded),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: AppColors.indigo),
            ],
          ),
          const Spacer(),
          SerifText('教材中心', fontSize: 15, color: AppColors.textOf(context)),
          const SizedBox(height: 3),
          MonoText('AI 智能检索教材', fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  // 每日一例（主色，突出）
  Widget _dailyCaseBlock() {
    final no = _dailyCaseData?['scheduleId'] as int? ?? 213;
    final title = _dailyCaseData?['caseTitle'] as String? ?? '每日一例训练';
    final department = _dailyCaseData?['department'] as String? ?? '心血管';
    final estimatedTime = _dailyCaseData?['estimatedTime'] as String? ?? '5 分钟';

    return _blockShell(
      bg: AppColors.primaryOf(context),
      height: 150,
      onTap: () => context.goNamed(RouteNames.studentCaseMarket),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MonoText(
                'AI 每日一例 · No.$no',
                fontSize: 10,
                color: AppColors.onPrimarySoftOf(context),
                letterSpacing: 0.1,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.goNamed(RouteNames.studentCaseMarket),
                child: Row(
                  children: [
                    Text(
                      '病例中心',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onPrimarySoftOf(context),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 14, color: AppColors.onPrimarySoftOf(context)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimaryOf(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              MonoText('$department · $estimatedTime',
                  fontSize: 10, color: AppColors.onPrimarySoftOf(context)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.pushNamed(RouteNames.dailyCase),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimaryOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '开始训练',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 待办作业（琥珀）
  Widget _todoBlock() {
    final total = _isLoadingAssignments
        ? 3
        : (_assignmentsData?['total'] as int? ?? 3);
    return _blockShell(
      bg: AppColors.amberSoftOf(context),
      height: 110,
      onTap: () => context.pushNamed(RouteNames.todoAssignments),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(AppColors.amber, Icons.task_alt_rounded),
              const Spacer(),
              Text(
                '$total',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
          const Spacer(),
          SerifText('待办作业', fontSize: 14, color: AppColors.textOf(context)),
          MonoText('AI 批阅 · $total 项未完成', fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  // 基础题训练（苔藓绿）
  Widget _trainingBlock() {
    final accuracy = ((_questionStats?['accuracy'] as num?)?.toDouble() ?? 0.0);
    final answered = (_questionStats?['totalAnswered'] as num?)?.toInt() ?? 0;
    return _blockShell(
      bg: AppColors.mossTintOf(context),
      height: 110,
      onTap: () => context.pushNamed(RouteNames.questionTraining),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(AppColors.primaryOf(context), Icons.quiz_rounded),
              const Spacer(),
              Text(
                accuracy == 0 ? '--' : '${(accuracy * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOf(context),
                ),
              ),
            ],
          ),
          const Spacer(),
          SerifText('基础题训练', fontSize: 14, color: AppColors.textOf(context)),
          MonoText('AI 训练 · 已做 $answered 题', fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  Widget _blockIcon(Color color, IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// 首页全局检索对话框
class _HomeSearchDialog extends StatefulWidget {
  const _HomeSearchDialog();

  @override
  State<_HomeSearchDialog> createState() => _HomeSearchDialogState();
}

class _HomeSearchDialogState extends State<_HomeSearchDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      title: Text(
        '智能检索',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context)),
      ),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '教材 / 知识点 / 题目 / 病例',
          hintStyle: TextStyle(color: AppColors.text4Of(context)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.surfaceEdgeOf(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.primaryOf(context), width: 1.5),
          ),
        ),
        style: TextStyle(color: AppColors.textOf(context)),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text('取消',
              style: TextStyle(color: AppColors.text3Of(context))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctl.text),
          child: Text(
            '搜索',
            style: TextStyle(
                color: AppColors.primaryOf(context),
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// 热力图网格（力扣同款：列=周，行=周一~周日，横向滑动，跨年时年份淡入淡出）
class _HeatmapGrid extends StatefulWidget {
  final List<dynamic>? activityDays;

  const _HeatmapGrid({this.activityDays});

  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  static const double _gap = 3; // 格子间距
  static const double _cell = 12; // 格子大小（力扣风格，紧凑）
  static const int _monthCount = 12; // 显示最近 12 个月
  static const double _monthLabelHeight = 14; // 顶部月份标签行高
  static const double _monthDividerWidth = 16; // 月份分隔区宽度

  final ScrollController _scroll = ScrollController();

  // 月份视图数据：每月一个，含日历网格
  late List<_MonthView> _months;
  // 每月内容起始 X 坐标（累计宽度）
  late List<double> _monthStartX;
  // 当前滑动可见区域跨越的年份（用于顶部淡入淡出）
  int _leftYear = 0;
  int _rightYear = 0;
  bool _leftVisible = false;
  bool _rightVisible = false;

  @override
  void initState() {
    super.initState();
    _build();
    _scroll.addListener(_onScroll);
    // 初始定位到最右（当前月）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(_HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityDays != widget.activityDays) {
      _build();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 按 yyyy-MM-dd 聚合 completedCount
  Map<String, int> _countByDate() {
    final result = <String, int>{};
    final days = widget.activityDays;
    if (days == null) return result;
    for (final d in days) {
      final m = d as Map<String, dynamic>;
      final dateStr = m['date'] as String? ?? '';
      final count = (m['completedCount'] as num?)?.toInt() ?? 0;
      if (dateStr.isNotEmpty) result[dateStr] = count;
    }
    return result;
  }

  void _build() {
    final today = DateTime.now();
    final counts = _countByDate();
    final isMock = widget.activityDays == null;
    final rnd = [0, 0, 0, 1, 1, 2, 2, 3, 4];

    _months = [];
    // 从当前月往前推 _monthCount 个月，生成每月日历视图
    for (int i = _monthCount - 1; i >= 0; i--) {
      final month = DateTime(today.year, today.month - i, 1);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      // 当前月只显示到今天为止，今天之后不出格子
      final lastDay = (month.year == today.year && month.month == today.month)
          ? today.day
          : daysInMonth;
      // 1 号是周几（0=周一 ... 6=周日）
      final offset = (month.weekday - DateTime.monday) % 7;
      // 需要的列数（每周一列），只覆盖到今天
      final rows = ((offset + lastDay) / 7).ceil();

      // 生成展平等级：长度为 rows*7，每天落在正确星期位置，无效位置为 -1
      final levels = List<int>.filled(rows * 7, -1);
      for (int d = 0; d < lastDay; d++) {
        final date = DateTime(month.year, month.month, d + 1);
        final key = _fmt(date);
        int lvl;
        if (isMock) {
          final idx = date.day + date.month * 7 + date.year;
          lvl = idx % 10 > 4 ? rnd[(idx * 3 + 1) % rnd.length] : 0;
        } else {
          lvl = _levelFor(counts[key] ?? 0);
        }
        levels[offset + d] = lvl;
      }

      _months.add(_MonthView(
        year: month.year,
        month: month.month,
        offset: offset,
        daysInMonth: daysInMonth,
        rows: rows,
        levels: levels,
      ));
    }

    // 计算每月内容的起始 X 坐标（周宽 = rows * (cell+gap)，月份间加分隔）
    _monthStartX = [];
    double x = 0;
    for (int i = 0; i < _months.length; i++) {
      _monthStartX.add(x);
      final monthWidth = _months[i].rows * (_cell + _gap);
      x += monthWidth + (i == _months.length - 1 ? 0 : _monthDividerWidth);
    }
  }

  int _levelFor(int count) {
    if (count == 0) return 0;
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    final viewport = _scroll.position.viewportDimension;

    // 找到当前可见区域覆盖的月份，取两端的年份
    int startMonth = 0;
    int endMonth = 0;
    for (int i = 0; i < _monthStartX.length; i++) {
      if (_monthStartX[i] <= offset) startMonth = i;
      if (_monthStartX[i] <= offset + viewport) endMonth = i;
    }
    startMonth = startMonth.clamp(0, _months.length - 1);
    endMonth = endMonth.clamp(0, _months.length - 1);

    final leftYear = _months[startMonth].year;
    final rightYear = _months[endMonth].year;
    final crossYear = leftYear != rightYear;
    setState(() {
      _leftYear = _leftVisible ? _leftYear : leftYear;
      _rightYear = rightYear;
      _leftVisible = crossYear;
      _rightVisible = crossYear;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.paper2Of(context),
      AppColors.heatL1,
      AppColors.heatL2,
      AppColors.heatL3,
      AppColors.heatL4,
    ];
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    const shownWeekday = {0, 1, 2, 3, 4, 5, 6}; // 周一~周日全部显示
    const weekdayIndex = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6};

    // 顶部月份标签行高（用于星期标签与格子顶部对齐）
    const double labelH = _monthLabelHeight;

    // 左侧星期标签列：行结构与格子完全一致（每行 _cell，底部 gap），逐行对齐
    final weekdayColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int wd = 0; wd < 7; wd++)
          Padding(
            padding: EdgeInsets.only(bottom: wd == 6 ? 0 : _gap),
            child: Container(
              height: _cell,
              alignment: Alignment.centerLeft,
              child: shownWeekday.contains(wd)
                  ? Text(
                      weekdayLabels[weekdayIndex[wd]!],
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.text4Of(context),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );

    // 按月份分块：每个月份块 = 月份标签 + 转置日历网格（列=周，行=周一到周日）
    final monthBlocks = <Widget>[];
    for (int g = 0; g < _months.length; g++) {
      final mv = _months[g];
      final isLast = g == _months.length - 1;

      // 转置网格：每列是一周，列内 7 行从上到下为周一到周日
      final grid = Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(mv.rows, (week) {
          return Padding(
            padding: EdgeInsets.only(right: week == mv.rows - 1 ? 0 : _gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (wd) {
                final idx = week * 7 + wd; // wd: 0=周一 ... 6=周日
                final lvl = mv.levels[idx];
                // 无效位置（今天之后 / 月初空位）用透明占位，保持 7 行对齐
                return Padding(
                  padding: EdgeInsets.only(bottom: wd == 6 ? 0 : _gap),
                  child: Container(
                    width: _cell,
                    height: _cell,
                    decoration: BoxDecoration(
                      color: lvl < 0 ? Colors.transparent : colors[lvl.clamp(0, colors.length - 1)],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      );

      // 月份块（含顶部月份标签）
      monthBlocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: labelH,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '${mv.month}月',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            grid,
          ],
        ),
      );

      // 月份之间加分隔线（最后一个月份后不加）
      if (!isLast) {
        monthBlocks.add(
          Container(
            width: _monthDividerWidth,
            alignment: Alignment.center,
            child: Column(
              children: [
                const SizedBox(height: labelH + 4),
                Container(
                  width: 1,
                  height: _cell * 7 + _gap * 6,
                  color: AppColors.surfaceEdgeOf(context),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 横向内容：月份块水平排列
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: monthBlocks,
    );

    return SizedBox(
      height: labelH + 4 + _cell * 7 + _gap * 6, // 月份标签行 + 7 行格子
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: labelH + 4),
            child: weekdayColumn,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: content,
                ),
                // 左上角：上一年（跨年时淡入淡出）
                Positioned(
                  top: 0,
                  left: 0,
                  child: AnimatedOpacity(
                    opacity: _leftVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_leftYear',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
                // 右上角：下一年（跨年时淡入淡出）
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _rightVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$_rightYear',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text3Of(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单月日历视图数据
class _MonthView {
  final int year;
  final int month;
  final int offset; // 1 号落在周几（0=周一 ... 6=周日）
  final int daysInMonth;
  final int rows; // 该月需要的行数
  final List<int> levels; // 展平等级，非本月日期为 -1

  const _MonthView({
    required this.year,
    required this.month,
    required this.offset,
    required this.daysInMonth,
    required this.rows,
    required this.levels,
  });
}