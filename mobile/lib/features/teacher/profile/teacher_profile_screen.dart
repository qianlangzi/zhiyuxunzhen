import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 教师"我的"页面
class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  String _caseCount = '—';
  String _refCount = '—';
  String _avgRating = '—';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final service = TeacherService();
    try {
      final result = await service.getCaseList();
      if (!mounted) return;
      final list = result?['list'] as List<dynamic>? ?? [];
      setState(() {
        _caseCount = list.length.toString();
      });
    } catch (e) {
      // 兜底：加载异常不影响页面渲染，避免未处理异常
      debugPrint('loadProfileStats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.nickname ?? user?.realName ?? '老师';
    final initial = displayName.isNotEmpty ? displayName[0] : '师';

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTitleAppBar(tag: '内科教研 · 教师端', title: '我的'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileHero(
                      initial: initial,
                      displayName: displayName,
                      subtitle: '附属第一医院 · 心血管内科',
                      badge: '✓ 已认证',
                      avatarPath: user?.avatarPath,
                      onEdit: () => context.pushNamed(RouteNames.profileEditTeacher),
                    ),
                    ProfileStatsStrip(
                      stats: [
                        ProfileStat(_caseCount, '我的病例', AppColors.primary),
                        ProfileStat(_refCount, '累计引用', AppColors.amber),
                        ProfileStat(_avgRating, '平均评分', AppColors.indigo),
                      ],
                    ),
                    _buildTeachingSection(context),
                    _buildGeneralSection(context),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: MedicalDisclaimer(),
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

  Widget _buildTeachingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('教学工作'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.folder_outlined,
                  color: AppColors.primaryOf(context),
                  title: '我的病例',
                  onTap: () => context.goNamed(RouteNames.spConfig),
                ),
                ProfileMenuTile(
                  icon: Icons.dashboard_outlined,
                  color: AppColors.indigo,
                  title: '学情看板',
                  onTap: () => context.pushNamed(RouteNames.dashboard),
                ),
                ProfileMenuTile(
                  icon: Icons.history_outlined,
                  color: AppColors.vermilion,
                  title: '批阅历史',
                  onTap: () => context.pushNamed(RouteNames.review),
                ),
                ProfileMenuTile(
                  icon: Icons.storefront_outlined,
                  color: AppColors.amber,
                  title: '病例广场',
                  divider: false,
                  onTap: () => context.goNamed(RouteNames.caseMarket),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('账户'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.verified_user_outlined,
                  color: AppColors.primaryOf(context),
                  title: '资质认证',
                  onTap: () => AppFeedback.info(context, '资质认证 已通过'),
                ),
                ProfileMenuTile(
                  icon: Icons.settings_outlined,
                  color: AppColors.text3Of(context),
                  title: '设置',
                  onTap: () => context.pushNamed(RouteNames.settings),
                ),
                ProfileMenuTile(
                  icon: Icons.info_outline,
                  color: AppColors.text3Of(context),
                  title: '关于智愈寻真',
                  divider: false,
                  onTap: () => context.pushNamed(RouteNames.about),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}