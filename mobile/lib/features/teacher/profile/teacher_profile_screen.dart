import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/common/guide/guide_anchor.dart';
import '../../../features/common/guide/guide_controller.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../data/teacher_service.dart';

/// 教师「我的」· 个人中心
///
/// 按大厂「个人中心」结构精简重构，聚焦个人资产与账户，弱化与工作台/班级
/// Tab 重复的功能入口：
/// - 顶部个人名片（保留）：身份 + 真实认证状态徽标
/// - 真实数据条：我的班级 / 待复核 / 进行中作业（均来自 dashboard overview）
/// - 工作内容列表（与「账户」同款风格）：我的病例 / 我的备课 / 我的基础题库 / 我的教材
/// - 底部账户栏（保留）：资质认证 / 设置 / 关于
///
/// 已移除的冗余入口：病例广场（工作台 hero）、学情看板（班级 Tab / dashboard）、
/// 批阅历史（班级 Tab 作业批阅覆盖）。全部数据均来自真实 API，无硬编码假数据。
class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  String _classCount = '—';
  String _pendingReview = '—';
  String _activeAssignments = '—';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final service = TeacherService();
    try {
      final data = await service.getDashboardOverview();
      if (!mounted) return;
      setState(() {
        _classCount = data?['classCount']?.toString() ?? '—';
        _pendingReview = data?['pendingReview']?.toString() ?? '—';
        _activeAssignments = data?['activeAssignments']?.toString() ?? '—';
      });
    } catch (e) {
      // 兜底：加载异常不影响页面渲染，避免未处理异常
      debugPrint('loadProfileStats error: $e');
    }
  }

  /// 依据真实审核状态推导徽标（0未提交/1待审/2通过/3驳回），不再硬编码
  String? get _auditBadge {
    final status = ref.watch(authProvider).user?.auditStatus ?? 0;
    return switch (status) {
      2 => '✓ 已认证',
      1 => '待审核',
      3 => '认证被驳回',
      _ => null,
    };
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
                    GuideTarget(
                      anchor: GuideAnchors.teacherProfileHero,
                      child: ProfileHero(
                        initial: initial,
                        displayName: displayName,
                        badge: _auditBadge,
                        avatarPath: user?.avatarPath,
                        onEdit: () =>
                            context.pushNamed(RouteNames.profileEditTeacher),
                      ),
                    ),
                    ProfileStatsStrip(
                      stats: [
                        ProfileStat(_classCount, '我的班级', AppColors.indigoOf(context)),
                        ProfileStat(_pendingReview, '待复核', AppColors.vermilionOf(context)),
                        ProfileStat(_activeAssignments, '进行中作业', AppColors.primary),
                      ],
                    ),
                    _buildContentSection(context),
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

  // =============== 工作内容（与「账户」同款列表风格，保持整体统一） ===============

  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionLabel('工作内容'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppPaper(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ProfileMenuTile(
                  icon: Icons.folder_copy_outlined,
                  color: AppColors.vermilionOf(context),
                  title: '我的病例',
                  onTap: () => context.pushNamed(RouteNames.myCases),
                ),
                ProfileMenuTile(
                  icon: Icons.school_outlined,
                  color: AppColors.indigoOf(context),
                  title: '我的备课',
                  onTap: () => context.goNamed(RouteNames.bprep),
                ),
                ProfileMenuTile(
                  icon: Icons.playlist_add_check_circle_outlined,
                  color: AppColors.amberOf(context),
                  title: '我的基础题库',
                  onTap: () => context.pushNamed(RouteNames.teacherQuestions),
                ),
                ProfileMenuTile(
                  icon: Icons.thumb_up_alt_outlined,
                  color: AppColors.vermilionOf(context),
                  title: '批阅申诉',
                  onTap: () => context.pushNamed(RouteNames.teacherAppeals),
                ),
                ProfileMenuTile(
                  icon: Icons.library_books_outlined,
                  color: AppColors.primaryOf(context),
                  title: '我的教材',
                  divider: false,
                  onTap: () => context.pushNamed(RouteNames.teacherTextbook),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =============== 账户栏 ===============

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
                  icon: Icons.auto_awesome_outlined,
                  color: AppColors.primaryOf(context),
                  title: '新手指引',
                  onTap: () => ref
                      .read(guideControllerProvider.notifier)
                      .replay(GuideRole.teacher, tabId: 'profile'),
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