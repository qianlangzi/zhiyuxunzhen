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

/// 学生端首页 · 学习中心
class StudentHomeScreen extends ConsumerStatefulWidget {
const   StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  int _currentTab = 0;

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
                fontFamily: 'NotoSerifSC',
                fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
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
            const Text(
              '23',
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppColors.moss,
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
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              Row(
                children: [
                  const MonoText('近半年 182 天 · 完成 ', fontSize: 11),
                  const Text(
                    '142',
                    style: TextStyle(
                      color: AppColors.moss,
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
          _HeatmapGrid(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const MonoText('少', fontSize: 10),
              const SizedBox(width: 6),
              Row(
                children: [
                  _heatCell(AppColors.paper2),
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
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.moss,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child:               MonoText(
                '07.21',
                fontSize: 10,
              color: AppColors.paper.withOpacity(0.5),
              letterSpacing: 0.1,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MonoText(
                '每日一例 · No.213',
                fontSize: 11,
                color: Color(0xFFB8C9B8),
                letterSpacing: 0.14,
              ),
              const SizedBox(height: 8),
              const Text(
                '胸痛 2 小时伴大汗\n会是急性冠脉综合征吗？',
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC'],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.paper,
                  height: 1.25,
                  letterSpacing: -0.01,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _dailyMetaDot('心血管'),
                  const SizedBox(width: 12),
                  _dailyMetaDot('5 分钟'),
                  const SizedBox(width: 12),
                  _dailyMetaDot('标准'),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.goNamed(RouteNames.dailyCase),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '开始训练',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.moss,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.moss),
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
          decoration: const BoxDecoration(
            color: Color(0xFFB8C9B8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        MonoText(
          label,
          fontSize: 11,
          color: const Color(0xFFB8C9B8),
        ),
      ],
    );
  }

  // 待办作业
  Widget _buildTodoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '01',
          title: '待办作业',
          trailing: AppMoreLink(
            label: '全部 3 →',
            onTap: () => AppFeedback.info(context, '作业列表页即将开放'),
          ),
        ),
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
      ],
    );
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
          child: Column(
            children: [
              _weakRow('急性冠脉综合征', 0.42, AppColors.vermilion),
              _weakRow('肺栓塞鉴别', 0.55, AppColors.amber),
              _weakRow('慢性心衰分级', 0.61, AppColors.amber),
              _weakRow('消化道出血', 0.78, AppColors.moss),
            ],
          ),
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
  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  late List<int> _levels;

  @override
  void initState() {
    super.initState();
    // 生成模拟数据（26列 × 7行 = 182天）
    final rnd = [0, 0, 0, 1, 1, 2, 2, 3, 4];
    _levels = List.generate(
      26 * 7,
      (i) => (i * 7 + 3) % 10 > 4 ? rnd[(i * 3 + 1) % rnd.length] : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.paper2,
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
            color: colors[_levels[i]],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
