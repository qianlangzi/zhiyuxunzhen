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
const   StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  int _currentTab = 0;

  Map<String, dynamic>? _dailyCaseData;
  Map<String, dynamic>? _assignmentsData;
  List<dynamic>? _weakPointsData;
  Map<String, dynamic>? _overviewData;
  bool _isLoadingDailyCase = true;
  bool _isLoadingAssignments = true;
  bool _isLoadingWeaknesses = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final service = StudentService();
    final dailyCase = await service.getTodayDailyCase();
    final assignments = await service.getMyAssignments();
    final weaknesses = await service.getWeaknesses();
    final overview = await service.getReportOverview();
    if (mounted) {
      setState(() {
        _dailyCaseData = dailyCase;
        _assignmentsData = assignments;
        _weakPointsData = weaknesses;
        _overviewData = overview;
        _isLoadingDailyCase = false;
        _isLoadingAssignments = false;
        _isLoadingWeaknesses = false;
      });
    }
  }

  void _onTabTap(int index) {
    if (index == 0) return; // 已在首页
    if (index == 1) context.goNamed(RouteNames.chat);
    if (index == 2) context.goNamed(RouteNames.mistakes);
    if (index == 3) context.goNamed(RouteNames.studentProfile);
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
                    _buildDailyCard(),
                    _buildTodoSection(),
                    _buildWeakPointsSection(),
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
       SizedBox(height: 4),
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
   padding: EdgeInsets.all(16),
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

  // 每日一例卡片
  Widget _buildDailyCard() {
    if (_isLoadingDailyCase) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.moss,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.paper),
            ),
          ),
        ),
      );
    }

    final dateStr = _dailyCaseData?['date'] as String? ?? '07.21';
    final caseNo = _dailyCaseData?['caseNo'] as int? ?? 213;
    final title = _dailyCaseData?['title'] as String? ?? '胸痛 2 小时伴大汗\n会是急性冠脉综合征吗？';
    final department = _dailyCaseData?['department'] as String? ?? '心血管';
    final estimatedTime = _dailyCaseData?['estimatedTime'] as String? ?? '5 分钟';
    final difficulty = _dailyCaseData?['difficulty'] as String? ?? '标准';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child:               MonoText(
              dateStr,
              fontSize: 10,
              color: AppColors.onPrimaryOf(context).withValues(alpha: 0.5),
              letterSpacing: 0.1,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText(
                '每日一例 · No.$caseNo',
                fontSize: 11,
                color: AppColors.onPrimarySoftOf(context),
                letterSpacing: 0.14,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimaryOf(context),
                  height: 1.25,
                  letterSpacing: -0.01,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _dailyMetaDot(department),
                  const SizedBox(width: 12),
                  _dailyMetaDot(estimatedTime),
                  const SizedBox(width: 12),
                  _dailyMetaDot(difficulty),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.goNamed(RouteNames.dailyCase),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '开始训练',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryOf(context),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryOf(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyMetaDot(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.onPrimarySoftOf(context),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        MonoText(
          label,
          fontSize: 11,
          color: AppColors.onPrimarySoftOf(context),
        ),
      ],
    );
  }

  // 待办作业
  Widget _buildTodoSection() {
    final totalCount = _isLoadingAssignments
        ? 3
        : (_assignmentsData?['total'] as int? ?? 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '01',
          title: '待办作业',
          trailing: AppMoreLink(
            label: '全部 $totalCount →',
            onTap: () => AppFeedback.info(context, '作业列表页即将开放'),
          ),
        ),
if (_isLoadingAssignments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          ..._buildTodoItems(),
      ],
    );
  }

  List<Widget> _buildTodoItems() {
    final records = _assignmentsData?['records'] as List<dynamic>?;

    if (records != null && records.isNotEmpty) {
      return records.map((r) {
        final item = r as Map<String, dynamic>;
        final title = item['title'] as String? ?? '（未命名作业）';
        final teacher = item['teacher'] as String? ?? '';
        final department = item['department'] as String? ?? '';
        final deadline = item['deadline'] as String? ?? '';
        final status = item['status'] as String? ?? '';

        final metaItems = <String>[];
        if (teacher.isNotEmpty) metaItems.add('$teacher 老师');
        if (department.isNotEmpty) metaItems.add(department);
        if (deadline.isNotEmpty) metaItems.add('截止 $deadline');

        final isUrgent = item['urgent'] as bool? ?? false;
        final tagColor = isUrgent ? AppColors.vermilion : AppColors.moss;

        return _todoItem(
          tagColor: tagColor,
          title: title,
          metaItems: metaItems.isEmpty ? ['待处理'] : metaItems,
          urgentDeadline: isUrgent,
          onTap: () => context.pushNamed(RouteNames.chat),
        );
      }).toList();
    }

    // 默认显示（API 返回 null 时使用）
    return [
      _todoItem(
        tagColor: AppColors.vermilion,
        title: '心绞痛病例问诊 · 大病历',
        metaItems: const ['王老师', '心血管内科', '截止 07.22 23:59'],
        urgentDeadline: true,
        onTap: () => context.pushNamed(RouteNames.chat),
      ),
      _todoItem(
        tagColor: AppColors.amber,
        title: '慢阻肺急性加重 · 鉴别诊断',
        metaItems: const ['李老师', '呼吸内科', '截止 07.25 23:59'],
        onTap: () => context.pushNamed(RouteNames.chat),
      ),
      _todoItem(
        tagColor: AppColors.moss,
        title: '肝硬化腹水 · 自主训练',
        metaItems: const ['消化内科', '已完成问诊，待提交病历'],
        onTap: () => AppFeedback.info(context, '该作业已完成问诊，待提交大病历'),
      ),
    ];
  }

  Widget _todoItem({
    required Color tagColor,
    required String title,
    required List<String> metaItems,
    bool urgentDeadline = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
   margin: EdgeInsets.only(bottom: 8),
   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(2),
            ),
            constraints: const BoxConstraints(minHeight: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
         style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textOf(context),
                  ),
                ),
         SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  children: metaItems.map((m) {
                    final isUrgent = urgentDeadline && m.contains('截止');
                    return MonoText(
                      m,
                      fontSize: 11,
                      color: isUrgent ? AppColors.vermilion : AppColors.text3Of(context),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      Icon(Icons.chevron_right, size: 14, color: AppColors.text3Of(context)),
        ],
      ),
      ),
    );
  }

  // 薄弱知识点
  Widget _buildWeakPointsSection() {
    final List<dynamic> weakPoints = _weakPointsData ?? const [];
    final List<Widget> rows;
    if (_isLoadingWeaknesses) {
      rows = [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    } else if (weakPoints.isEmpty) {
      rows = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: MonoText(
              '暂无薄弱知识点数据',
              fontSize: 12,
              color: AppColors.text3Of(context),
            ),
          ),
        ),
      ];
    } else {
      rows = weakPoints.map((item) {
        final m = item as Map<String, dynamic>;
        final name = m['knowledgeTag'] as String? ?? '';
        final score = (m['weaknessScore'] as num?)?.toDouble() ?? 0.0;
        final color = score < 0.5
            ? AppColors.vermilion
            : score < 0.7
                ? AppColors.amber
                : AppColors.moss;
        return _weakRow(name, score, color);
      }).toList();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '02',
          title: '薄弱知识点',
          trailing: AppMoreLink(
            label: '补救路径 →',
            onTap: () => context.pushNamed(RouteNames.reviewReport),
          ),
        ),
        AppPaper(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _weakRow(String name, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              name,
       style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppProgressBar(
              value: score,
              height: 6,
              foregroundColor: color,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              score.toStringAsFixed(2),
              textAlign: TextAlign.right,
       style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
        ],
      ),
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
