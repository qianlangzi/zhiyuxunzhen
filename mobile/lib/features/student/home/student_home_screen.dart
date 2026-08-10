import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/bottom_tab_bar.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/models.dart';
import '../../../shared/utils/feedback.dart';
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
  int _currentTab = 0;

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

  void _onTabTap(int index) {
    if (index == 0) return; // 已在首页
    if (index == 1) context.goNamed(RouteNames.studentCaseMarket);
    if (index == 2) context.goNamed(RouteNames.mistakes);
    if (index == 3) context.goNamed(RouteNames.studentProfile);
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
            // Bottom Tab
            StudentTabBar(currentIndex: _currentTab, onTap: _onTabTap),
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
                  const MonoText('近半年 182 天 · 完成 ', fontSize: 11),
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
          MonoText('按知识点匹配教材', fontSize: 10, color: AppColors.text3Of(context)),
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
                '每日一例 · No.$no',
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
          MonoText('$total 项未完成', fontSize: 10, color: AppColors.text3Of(context)),
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
          MonoText('已做 $answered 题', fontSize: 10, color: AppColors.text3Of(context)),
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

// 热力图网格
class _HeatmapGrid extends StatefulWidget {
  final List<dynamic>? activityDays;

  const _HeatmapGrid({this.activityDays});

  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  late List<int> _levels;

  @override
  void initState() {
    super.initState();
    _levels = _buildLevels();
  }

  @override
  void didUpdateWidget(_HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityDays != widget.activityDays) {
      _levels = _buildLevels();
    }
  }

  /// 根据 activityDays 计算近 182 天的热力等级；数据缺失时回退模拟数据。
  List<int> _buildLevels() {
    final days = widget.activityDays;
    if (days == null) {
      // 加载中或接口失败：使用模拟数据（26列 × 7行 = 182天）
      final rnd = [0, 0, 0, 1, 1, 2, 2, 3, 4];
      return List.generate(
        26 * 7,
        (i) => (i * 7 + 3) % 10 > 4 ? rnd[(i * 3 + 1) % rnd.length] : 0,
      );
    }
    // date(yyyy-MM-dd) → completedCount
    final countByDate = <String, int>{};
    for (final d in days) {
      final m = d as Map<String, dynamic>;
      final dateStr = m['date'] as String? ?? '';
      final count = (m['completedCount'] as num?)?.toInt() ?? 0;
      if (dateStr.isNotEmpty) countByDate[dateStr] = count;
    }
    final today = DateTime.now();
    return List.generate(26 * 7, (i) {
      final day = today.subtract(Duration(days: 26 * 7 - 1 - i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final count = countByDate[key] ?? 0;
      if (count == 0) return 0;
      if (count == 1) return 1;
      if (count == 2) return 2;
      if (count <= 4) return 3;
      return 4;
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 26,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemCount: _levels.length,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: colors[_levels[i].clamp(0, colors.length - 1)],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}