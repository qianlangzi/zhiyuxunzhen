import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/common/guide/guide_controller.dart';
import '../../../routes/route_names.dart';

/// 学生"我的"页面
///
/// 这里只放「身份 + 入口」，不放统计数字：
/// 累计训练 / 连续天数 / OSCE 均分这些已在「成长」Tab 有完整叙事，
/// 重复展示会稀释成长页的焦点，故不再在本页铺数据条。
class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
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
            const AppTitleAppBar(tag: '新医科 · 学生端', title: '我的'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiseIn(
                      child: ProfileHero(
                        initial: initial,
                        displayName: displayName,
                        subtitle: subtitle,
                        avatarPath: user?.avatarPath,
                        onEdit: () => context.pushNamed(RouteNames.profileEdit),
                      ),
                    ),
                    RiseIn(
                      delay: const Duration(milliseconds: 80),
                      child: _buildStudySection(context),
                    ),
                    RiseIn(
                      delay: const Duration(milliseconds: 140),
                      child: _buildGeneralSection(context),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: RiseIn(
                        delay: Duration(milliseconds: 180),
                        child: MedicalDisclaimer(),
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

  Widget _buildStudySection(BuildContext context) {
    // 入口统一：学习档案 / 错题本已归口「成长」Tab 的子级入口方块，
    // 本页不再重复挂入口，避免同一功能多处进入导致口径混乱。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('学习工具'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.thumb_up_alt_outlined,
                  color: AppColors.primaryOf(context),
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
                  icon: Icons.auto_awesome_outlined,
                  color: AppColors.primaryOf(context),
                  title: '新手指引',
                  onTap: () => ref
                      .read(guideControllerProvider.notifier)
                      .replay(GuideRole.student),
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
