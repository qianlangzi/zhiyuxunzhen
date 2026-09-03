import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../routes/route_names.dart';
import '../data/student_service.dart';
import '../growth/growth_stats.dart';

/// 学生"我的"页面
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  /// 成长统计（复用 GrowthStats，与成长页 / 学习档案页同一口径）
  GrowthStats _stats = GrowthStats.fromOverview(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final overview = await StudentService().getReportOverview();
    if (!mounted) return;
    setState(() => _stats = GrowthStats.fromOverview(overview));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.nickname ?? user?.realName ?? '同学';
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    final subtitleParts = <String>[];
    if (user != null) {
      if ((user.studentNumber ?? '').isNotEmpty)
        subtitleParts.add(user.studentNumber!);
      if ((user.major ?? '').isNotEmpty) subtitleParts.add(user.major!);
      if ((user.grade ?? '').isNotEmpty) subtitleParts.add(user.grade!);
    }
    final subtitle = subtitleParts.join(' · ');

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTitleAppBar(tag: '内科教研 · 学生端', title: '我的'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileHero(
                      initial: initial,
                      displayName: displayName,
                      subtitle: subtitle,
                      avatarPath: user?.avatarPath,
                      onEdit: () => context.pushNamed(RouteNames.profileEdit),
                    ),
                    ProfileStatsStrip(
                      stats: [
                        ProfileStat('${_stats.totalTrainings}', '累计训练',
                            AppColors.primary),
                        ProfileStat('${_stats.streakDays}', '连续天数',
                            AppColors.amberOf(context)),
                        ProfileStat(
                            _stats.hasAbility
                                ? _stats.osceAvg.toStringAsFixed(1)
                                : '—',
                            'OSCE 均分',
                            AppColors.indigoOf(context)),
                      ],
                    ),
                    _buildStudySection(context),
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

  Widget _buildStudySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('学习资源'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.folder_copy_outlined,
                  color: AppColors.moss,
                  title: '学习档案',
                  onTap: () => context.pushNamed(RouteNames.learningArchive),
                ),
                ProfileMenuTile(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.vermilionOf(context),
                  title: '错题本',
                  onTap: () => context.pushNamed(RouteNames.mistakeBook),
                ),
                ProfileMenuTile(
                  icon: Icons.thumb_up_alt_outlined,
                  color: AppColors.moss,
                  title: '批阅申诉',
                  onTap: () => context.pushNamed(RouteNames.studentAppeals),
                ),
                ProfileMenuTile(
                  icon: Icons.history_edu_outlined,
                  color: AppColors.amberOf(context),
                  title: '每日一例',
                  divider: false,
                  onTap: () => context.pushNamed(RouteNames.dailyCase),
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
        const ProfileSectionLabel('通用'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.settings_outlined,
                  color: AppColors.text3Of(context),
                  title: '设置',
                  onTap: () => context.pushNamed(RouteNames.settings),
                ),
                ProfileMenuTile(
                  icon: Icons.feedback_outlined,
                  color: AppColors.vermilionOf(context),
                  title: '意见反馈',
                  onTap: () => context.pushNamed(RouteNames.feedback),
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
