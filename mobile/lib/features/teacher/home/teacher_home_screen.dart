import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 教师首页 · 工作台
class TeacherHomeScreen extends ConsumerStatefulWidget {
  const TeacherHomeScreen({super.key});
  @override
  ConsumerState<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends ConsumerState<TeacherHomeScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final data = await TeacherService().getDashboardOverview();
    if (mounted) {
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTitleAppBar(
              tag: '内科教研 · 教师端',
              title: '王老师 · 工作台',
              action: AppPrimaryButton(
                label: '+ 新建病例',
                small: true,
                onPressed: () => context.goNamed(RouteNames.spConfig),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(context),
                          const SizedBox(height: 20),
                          _buildStats(context),
                          const SizedBox(height: 12),
                          _buildTextbookEntry(context),
                          const SizedBox(height: 20),
                          _buildFeatureGrid(context),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '下午好，王老师',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
            height: 1.15,
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 4),
        MonoText('附属第一医院 · 心血管内科 · 带教 3 个班级', fontSize: 12),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    final data = _dashboardData;
    final pendingReview = data?['pendingReview']?.toString() ?? '12';
    final activeAssignments = data?['activeAssignments']?.toString() ?? '3';
    final myCases = data?['myCases']?.toString() ?? '28';

    return Row(
      children: [
        _statCard(context, pendingReview, '待复核', AppColors.vermilion, urgent: true),
        const SizedBox(width: 8),
        _statCard(context, activeAssignments, '进行作业', AppColors.textOf(context)),
        const SizedBox(width: 8),
        _statCard(context, myCases, '我的病例', AppColors.textOf(context)),
      ],
    );
  }

  Widget _statCard(BuildContext context, String num, String label, Color color, {bool urgent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: urgent ? AppColors.vermilionSoftOf(context) : AppColors.surfaceOf(context),
          border: Border.all(color: urgent ? AppColors.vermilionSoftOf(context) : AppColors.surfaceEdgeOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Stack(
          children: [
            if (urgent)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.vermilion,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  num,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1,
                    letterSpacing: -0.02,
                  ),
                ),
                const SizedBox(height: 4),
                MonoText(label, fontSize: 11, color: AppColors.text3Of(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextbookEntry(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed(RouteNames.teacherTextbook),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.indigoSoftOf(context), AppColors.surfaceOf(context)],
          ),
          border: Border.all(color: AppColors.indigoSoftOf(context)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 20, color: AppColors.indigo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SerifText('教材制作', fontSize: 14, color: AppColors.textOf(context)),
                  const SizedBox(height: 2),
                  MonoText('AI 向量化教材 · 供学生智能查阅', fontSize: 10, color: AppColors.text3Of(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.indigo),
          ],
        ),
      ),
    );
  }

  // 功能小模块（bento 网格，同期学生端首页风格）
  Widget _buildFeatureGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: _reviewCard(context)),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _classCard(context)),
          ],
        ),
        const SizedBox(height: 12),
        _marketCard(context),
      ],
    );
  }

  /// 待批阅（红色，突出）
  Widget _reviewCard(BuildContext context) {
    final pendingCount = _dashboardData?['pendingReview']?.toString() ?? '12';
    return _blockShell(
      context,
      bg: AppColors.vermilionSoftOf(context),
      height: 120,
      onTap: () => context.goNamed(RouteNames.review),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(context, AppColors.vermilion, Icons.fact_check_rounded),
              const Spacer(),
              Text(
                pendingCount,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.vermilion,
                ),
              ),
            ],
          ),
          const Spacer(),
          SerifText('待批阅', fontSize: 14, color: AppColors.textOf(context)),
          const SizedBox(height: 3),
          MonoText('AI 批阅 · $pendingCount 项待复核', fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  /// 班级概览（靛蓝）
  Widget _classCard(BuildContext context) {
    final classes = (_dashboardData?['classes'] as List<dynamic>?)?.length ?? 2;
    return _blockShell(
      context,
      bg: AppColors.indigoSoftOf(context),
      height: 120,
      onTap: () => context.goNamed(RouteNames.assignment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(context, AppColors.indigo, Icons.groups_rounded),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: AppColors.indigo),
            ],
          ),
          const Spacer(),
          SerifText('班级概览', fontSize: 14, color: AppColors.textOf(context)),
          const SizedBox(height: 3),
          MonoText('带教 · $classes 个班级', fontSize: 10, color: AppColors.text3Of(context)),
        ],
      ),
    );
  }

  /// 病历广场动态（苔藓绿）
  Widget _marketCard(BuildContext context) {
    final dynamicData = _dashboardData?['marketDynamic'] as Map<String, dynamic>?;
    final totalRefs = dynamicData?['totalRefs'] as String? ?? '23';
    final rating = dynamicData?['rating'] as String? ?? '4.8';
    return _blockShell(
      context,
      bg: AppColors.mossTintOf(context),
      height: 96,
      onTap: () => context.goNamed(RouteNames.caseMarket),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _blockIcon(context, AppColors.moss, Icons.public_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText('病历广场动态', fontSize: 14, color: AppColors.textOf(context)),
                    const SizedBox(height: 2),
                    MonoText('累计引用 $totalRefs 次 · 评分 $rating', fontSize: 10, color: AppColors.text3Of(context)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: AppColors.moss),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blockShell(
    BuildContext context, {
    required Color bg,
    required VoidCallback onTap,
    required Widget child,
    double? height,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
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

  Widget _blockIcon(BuildContext context, Color color, IconData icon) {
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