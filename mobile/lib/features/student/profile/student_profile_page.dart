import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../shared/widgets/widgets.dart';

/// 学生个人中心
class StudentProfilePage extends ConsumerWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState state = ref.watch(authControllerProvider);
    final UserModel? user = state.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildProfileCard(user)),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _buildStatCard(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _buildMenuCard(context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _buildDisclaimer(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: _buildLogout(context, ref),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.navBarHeight)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserModel? user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding, AppDimens.grid8, AppDimens.pagePadding, AppDimens.grid5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.bgGradientTop, AppColors.bg],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandSoft,
              border: Border.all(color: AppColors.line, width: 1),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded,
                size: 32, color: AppColors.brand),
          ),
          const SizedBox(width: AppDimens.grid4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      user?.displayName ?? '同学',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: AppDimens.grid2),
                      Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.grid2, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '学生',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user?.orgName ?? '临床 2203 班',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '账号：${user?.username ?? '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.soft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ZyStatCard(
              label: '连续练习',
              value: '12',
              detail: '天',
              tone: StatTone.brand,
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ZyStatCard(
              label: '完成训练',
              value: '38',
              detail: '次',
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ZyStatCard(
              label: '本月平均',
              value: '78',
              detail: '分',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context) {
    final List<_MenuItem> items = <_MenuItem>[
      _MenuItem(
        icon: Icons.history_rounded,
        title: '训练历史',
        subtitle: '查看最近的训练记录与反馈',
        onTap: () => context.go('/student/feedback'),
      ),
      _MenuItem(
        icon: Icons.bookmark_outline_rounded,
        title: '收藏病例',
        subtitle: '快速访问重点练习',
        onTap: () => context.go('/student/cases'),
      ),
      _MenuItem(
        icon: Icons.notifications_none_rounded,
        title: '消息通知',
        subtitle: '作业提醒、批阅结果',
        onTap: () {},
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        title: '应用设置',
        subtitle: '账号、隐私与缓存',
        onTap: () {},
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: ZyCard(
        child: Column(
          children: items
              .map((_MenuItem item) => ZyListTile(
                    title: item.title,
                    subtitle: item.subtitle,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, size: 18, color: AppColors.brand),
                    ),
                    onTap: item.onTap,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.grid4),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.health_and_safety_outlined,
                size: 18, color: AppColors.warning),
            const SizedBox(width: AppDimens.grid2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '医学免责声明',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '本应用仅供医学教学训练使用，不能替代临床判断和真实医疗决策。',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(authControllerProvider.notifier).logout();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.dangerSoft, width: 1),
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('退出登录'),
      ),
    );
  }
}

class _MenuItem {
  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
