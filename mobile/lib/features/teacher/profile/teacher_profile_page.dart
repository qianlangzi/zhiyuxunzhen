import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师个人中心：身份、教学概况、常用入口与免责
class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState state = ref.watch(authControllerProvider);
    final UserModel? user = state.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _IdentityCard(user: user)),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid5)),
          const SliverToBoxAdapter(child: _TeachingOverview()),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid6)),
          const SliverToBoxAdapter(child: _MenuSection()),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          const SliverToBoxAdapter(child: _Disclaimer()),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid6)),
          SliverToBoxAdapter(child: _LogoutButton(ref: ref)),
          const SliverToBoxAdapter(
              child:
                  SizedBox(height: AppDimens.grid8 + AppDimens.navBarHeight)),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding, AppDimens.grid8, AppDimens.pagePadding, 0),
      child: Row(
        children: <Widget>[
          Image.asset(
            'assets/images/brand-logo.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            semanticLabel: '知语寻真 Logo',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(user?.displayName ?? '老师', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(user?.orgName ?? '附属一院心内科', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.brand),
                    const SizedBox(width: 4),
                    Text('教师',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.brandStrong)),
                    const SizedBox(width: 6),
                    Text('·', style: AppTextStyles.caption),
                    const SizedBox(width: 6),
                    Text(user?.credentialStatus ?? '资质已认证',
                        style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeachingOverview extends StatelessWidget {
  const _TeachingOverview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '教学概况'),
          const SizedBox(height: AppDimens.grid3),
          Row(
            children: const <Widget>[
              Expanded(child: _StatCell(label: '本月批阅', value: '126')),
              _StatDivider(),
              Expanded(child: _StatCell(label: '配置病例', value: '8')),
              _StatDivider(),
              Expanded(child: _StatCell(label: '活跃班级', value: '3')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(value, style: AppTextStyles.h3.copyWith(color: AppColors.brand)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.line,
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        children: <Widget>[
          ZyListTile(
            leading: const Icon(Icons.group_outlined,
                size: 20, color: AppColors.brand),
            title: '我的班级',
            subtitle: '查看学生进度与作业',
            onTap: () => context.go('/teacher/assignments'),
          ),
          ZyListTile(
            leading: const Icon(Icons.layers_outlined,
                size: 20, color: AppColors.brand),
            title: '我的病例',
            subtitle: '已配置和草稿病例',
            onTap: () => context.go('/teacher/cases'),
          ),
          ZyListTile(
            leading: const Icon(Icons.bar_chart_outlined,
                size: 20, color: AppColors.brand),
            title: '教学洞察',
            subtitle: '班级薄弱点分析',
            onTap: () => context.go('/teacher'),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.grid4),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.health_and_safety_outlined,
                size: 18, color: AppColors.warning),
            const SizedBox(width: AppDimens.grid2),
            Expanded(
              child: Text(
                '本应用仅供医学教学训练使用，不能替代临床判断和真实医疗决策。',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
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
