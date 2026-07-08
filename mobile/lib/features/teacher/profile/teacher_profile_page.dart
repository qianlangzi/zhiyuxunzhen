import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师个人中心
class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

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
            child: const Icon(Icons.school_rounded,
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
                      user?.displayName ?? '老师',
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
                        '教师',
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
                  user?.orgName ?? '附属一院心内科',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.verified_user_rounded,
                        size: 12, color: AppColors.aqua),
                    const SizedBox(width: 4),
                    Text(
                      user?.credentialStatus ?? '资质已认证',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.aqua,
                      ),
                    ),
                  ],
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
              label: '本月批阅',
              value: '126',
              detail: '份',
              tone: StatTone.brand,
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ZyStatCard(
              label: '配置病例',
              value: '8',
              detail: '个',
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ZyStatCard(
              label: '活跃班级',
              value: '3',
              detail: '个',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context) {
    final List<_MenuItem> items = <_MenuItem>[
      _MenuItem(
        icon: Icons.group_outlined,
        title: '我的班级',
        subtitle: '查看学生进度与作业',
        onTap: () => context.go('/teacher/assignments'),
      ),
      _MenuItem(
        icon: Icons.layers_outlined,
        title: '我的病例',
        subtitle: '已配置和草稿病例',
        onTap: () => context.go('/teacher/cases'),
      ),
      _MenuItem(
        icon: Icons.bar_chart_outlined,
        title: '教学洞察',
        subtitle: '班级薄弱点分析',
        onTap: () => context.go('/teacher'),
      ),
      _MenuItem(
        icon: Icons.health_and_safety_outlined,
        title: '服务健康',
        subtitle: 'AI 模型与接口状态',
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
