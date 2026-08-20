import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../routes/route_names.dart';
import '../data/student_service.dart';

/// 学生"我的"页面
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  String _totalTraining = '—';
  String _osceAvg = '—';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final service = StudentService();
    final stats = await service.getQuestionStats();
    final overview = await service.getReportOverview();
    if (!mounted) return;

    setState(() {
      // 累计训练 = 总答题数
      final total = (stats?['totalAnswered'] as num?)?.toInt() ?? 0;
      _totalTraining = total.toString();

      // OSCE 均分 = abilityScores 各维度平均值
      final ability = overview?['abilityScores'] as Map<String, dynamic>?;
      if (ability != null && ability.isNotEmpty) {
        final avg = ability.values
            .map((v) => (v as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a + b) / ability.length;
        _osceAvg = avg.toStringAsFixed(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.nickname ?? user?.realName ?? '同学';
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    final subtitleParts = <String>[];
    if (user != null) {
      if ((user.studentNumber ?? '').isNotEmpty) subtitleParts.add(user.studentNumber!);
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
                        ProfileStat(_totalTraining, '累计训练', AppColors.primary),
                        ProfileStat('—', '连续天数', AppColors.amber),
                        ProfileStat(_osceAvg, 'OSCE 均分', AppColors.indigo),
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
                  icon: Icons.description_outlined,
                  color: AppColors.vermilion,
                  title: '错题本',
                  onTap: () => context.pushNamed(RouteNames.mistakes),
                ),
                ProfileMenuTile(
                  icon: Icons.assessment_outlined,
                  color: AppColors.indigo,
                  title: 'AI 复盘报告',
                  onTap: () => context.pushNamed(RouteNames.reviewReport),
                ),
                ProfileMenuTile(
                  icon: Icons.calendar_view_week_outlined,
                  color: AppColors.primaryOf(context),
                  title: '学习热力图',
                  onTap: () => context.goNamed(RouteNames.studentHome),
                ),
                ProfileMenuTile(
                  icon: Icons.history_edu_outlined,
                  color: AppColors.amber,
                  title: '每日一例历史',
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