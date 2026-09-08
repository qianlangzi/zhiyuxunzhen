import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';
import '../../auth/providers/auth_provider.dart';

/// 教师首页 · 工作台
///
/// 精简后的工作台只保留教师最核心的三件事，主次清晰、一眼直达：
/// - SP 病例广场（hero 大卡）：浏览 / 共享 / 创作标准病例
/// - 教材管理、基础题库（并排次卡）：内容库经营
/// - 我的病例（次级卡）：个人病例工作台
///
/// 不再重复出现的入口：
/// - 「发布 SP」为 SP 广场的子功能，已移入 SP 广场页内，不做独立模块展示
/// - 「作业批阅 / 班级管理」已由底部「班级」Tab 承接，首页不再重复
/// - 原「学情预警中心」已移除
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
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getDashboardOverview();
    } catch (e) {
      debugPrint('loadTeacherHome error: $e');
    }
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
              title: '$_displayName · 工作台',
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 16,
                        bottom: 100,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(context),
                          const SizedBox(height: 20),
                          _buildHeroMarket(context),
                          const SizedBox(height: 14),
                          _buildSubTools(context),
                          const SizedBox(height: 14),
                          _buildMyCases(context),
                          const SizedBox(height: 16),
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

  // ================= 问候区 =================

  Widget _buildGreeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '下午好，$_displayName',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textOf(context),
            height: 1.15,
            letterSpacing: -0.02,
          ),
        ),
        const SizedBox(height: 4),
        MonoText('带教 $_classCountText 个班级 · $_myCasesText 个病例', fontSize: 12),
      ],
    );
  }

  String get _displayName {
    final user = ref.watch(authProvider).user;
    final nickname = user?.nickname?.trim() ?? '';
    final realName = user?.realName.trim() ?? '';
    return nickname.isNotEmpty
        ? nickname
        : (realName.isNotEmpty ? realName : '老师');
  }

  String get _classCountText =>
      _dashboardData?['classCount']?.toString() ?? '—';
  String get _myCasesText => _dashboardData?['myCases']?.toString() ?? '—';

  // ================= SP 病例广场 hero =================

  Widget _buildHeroMarket(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: () => context.pushNamed(RouteNames.caseMarket),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.moss,
                AppColors.moss2,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '进入广场',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'SP 病例广场',
                style: TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontFamilyFallback: [
                    'Songti SC',
                    'STSong',
                    'Noto Serif CJK SC',
                    'Source Han Serif SC',
                  ],
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.02,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '智能检索内科病例 · 浏览引用 · 发布你的标准病人',
                style:
                    TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 16, color: Colors.white70),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '搜索病例标题 / 科室 / 作者',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 教材 / 题库 次卡 =================

  Widget _buildSubTools(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SubToolCard(
                icon: Icons.menu_book_rounded,
                color: AppColors.indigoOf(context),
                title: '教材管理',
                subtitle: '上传 · 审核分发',
                route: RouteNames.teacherTextbook,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: _SubToolCard(
                icon: Icons.playlist_add_check_circle_outlined,
                color: AppColors.amberOf(context),
                title: '基础题库',
                subtitle: '录入 · 审核 · 组卷',
                route: RouteNames.teacherQuestions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 每日病历批阅台：AI 初筛 + 复核 + 班级缺陷热力图
        _SubToolCard(
          icon: Icons.assignment_turned_in_rounded,
          color: AppColors.moss3Of(context),
          title: '每日病历批阅台',
          subtitle: 'AI 初筛 · 复核 · 缺陷热力',
          route: RouteNames.teacherMrConsole,
        ),
      ],
    );
  }

  // ================= 我的病例 次级卡 =================

  Widget _buildMyCases(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: () => context.pushNamed(RouteNames.myCases),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            boxShadow: AppShadow.card(context),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.vermilionSoftOf(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.folder_copy_outlined,
                      size: 22,
                      color: AppColors.vermilionOf(context),
                    ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SerifText(
                      '我的病例',
                      fontSize: 15,
                      color: AppColors.textOf(context),
                    ),
                    const SizedBox(height: 3),
                    MonoText(
                      '$_myCasesText 份 · 引用 / 编辑 / 发布',
                      fontSize: 11,
                      color: AppColors.text3Of(context),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.text3Of(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 次级工具卡（教材 / 题库）
class _SubToolCard extends StatelessWidget {
  const _SubToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: () => context.pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 20),
              SerifText(
                title,
                fontSize: 15,
                color: AppColors.textOf(context),
              ),
              const SizedBox(height: 2),
              MonoText(
                subtitle,
                fontSize: 10,
                color: AppColors.text3Of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
