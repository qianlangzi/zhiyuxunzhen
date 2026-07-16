import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';
import 'training_activity.dart';

/// 学生“我的”：身份、训练密度、菜单与免责
class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key});

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  String? _emptyDayNotice;

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    final UserModel? user = state.user;
    final LearningRepository repo = ref.watch(learningRepositoryProvider);
    final List<HeatmapDay> days = repo.heatmap();
    final DateTime now = DateTime.now();
    final TrainingActivitySummary summary =
        TrainingActivitySummary.fromDays(days, endDate: now);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _IdentityCard(user: user)),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid5)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _StatRow(summary: summary),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid6)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _HeatmapSection(
                days: days,
                endDate: now,
                emptyDayNotice: _emptyDayNotice,
                onDayTap: (HeatmapDay day) => _onDayTap(day),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid6)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _MenuSection(context: context),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _Disclaimer(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid6)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _LogoutButton(ref: ref),
            ),
          ),
          const SliverToBoxAdapter(
              child:
                  SizedBox(height: AppDimens.grid8 + AppDimens.navBarHeight)),
        ],
      ),
    );
  }

  void _onDayTap(HeatmapDay day) {
    if (day.completedCount == 0) {
      setState(() => _emptyDayNotice = '当天没有训练记录');
      return;
    }
    setState(() => _emptyDayNotice = null);
    _showDayDetail(day);
  }

  void _showDayDetail(HeatmapDay day) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(day.date, style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text('完成 ${day.completedCount} 次训练', style: AppTextStyles.body),
            if (day.activities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...day.activities.map(
                (String item) => ZyListTile(title: item, showDivider: false),
              ),
            ],
          ],
        ),
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
                Text(user?.displayName ?? '同学', style: AppTextStyles.h3),
                Text('${user?.orgName ?? '未设置班级'} · 学生',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});

  final TrainingActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCell(label: '训练天数', value: summary.activeDays),
        ),
        _StatDivider(),
        Expanded(
          child: _StatCell(label: '连续天数', value: summary.currentStreak),
        ),
        _StatDivider(),
        Expanded(
          child: _StatCell(label: '完成次数', value: summary.completedCount),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('$value',
            style: AppTextStyles.h3.copyWith(color: AppColors.brand)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.line,
    );
  }
}

class _HeatmapSection extends StatelessWidget {
  const _HeatmapSection({
    required this.days,
    required this.endDate,
    required this.emptyDayNotice,
    required this.onDayTap,
  });

  final List<HeatmapDay> days;
  final DateTime endDate;
  final String? emptyDayNotice;
  final ValueChanged<HeatmapDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZySectionHeader(title: '最近三个月'),
        const SizedBox(height: AppDimens.grid3),
        ZyActivityHeatmap(
          days: days,
          endDate: endDate,
          onDayTap: onDayTap,
        ),
        if (emptyDayNotice != null) ...<Widget>[
          const SizedBox(height: AppDimens.grid2),
          Text(emptyDayNotice!, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ZyListTile(
          leading: const Icon(Icons.history_rounded,
              size: 20, color: AppColors.brand),
          title: '训练历史',
          subtitle: '查看最近的训练记录与反馈',
          onTap: () => context.go('/student/feedback'),
        ),
        ZyListTile(
          leading: const Icon(Icons.bookmark_outline_rounded,
              size: 20, color: AppColors.brand),
          title: '收藏病例',
          subtitle: '快速访问重点练习',
          onTap: () => context.go('/student/cases'),
          showDivider: false,
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
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
    );
  }
}
