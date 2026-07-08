import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师概览：提交进度 + 待复核 + 班级薄弱点 + 待办
class TeacherOverviewPage extends ConsumerWidget {
  const TeacherOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeachingRepository teachingRepo = ref.watch(teachingRepositoryProvider);
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);

    final List<AssignmentModel> assignments = teachingRepo.assignments();
    final List<ReviewItem> reviewQueue = teachingRepo.reviewQueue();
    final List<WeaknessItem> weakness = teachingRepo.weakness();
    final List<CaseModel> cases = caseRepo.all();

    final int pending = reviewQueue
        .where((ReviewItem r) => r.status != '已复核')
        .length;
    final int submitted = assignments
        .fold<int>(0, (int p, AssignmentModel a) => p + a.submitted);
    final int total = assignments
        .fold<int>(0, (int p, AssignmentModel a) => p + a.total);
    final int completion = total == 0 ? 0 : (submitted * 100 / total).round();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: const ZyPageHead(kicker: '教学概览', title: '今天需要关注的教学进度'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding, AppDimens.grid3, AppDimens.pagePadding, 0),
              child: _buildStatsRow(completion, pending),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding, AppDimens.grid4, AppDimens.pagePadding, 0),
              child: _buildPendingCard(pending, context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding, AppDimens.grid4, AppDimens.pagePadding, 0),
              child: _buildWeaknessCard(weakness),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding, AppDimens.grid4, AppDimens.pagePadding, 0),
              child: _buildCasesCard(cases),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.navBarHeight)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int completion, int pending) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ZyStatCard(
            label: '提交进度',
            value: '$completion%',
            detail: '按当前作业统计',
            tone: StatTone.brand,
          ),
        ),
        const SizedBox(width: AppDimens.grid3),
        Expanded(
          child: ZyStatCard(
            label: '待复核',
            value: '$pending',
            detail: '保留人工最终判断',
            tone: pending > 0 ? StatTone.warning : StatTone.neutral,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(int pending, BuildContext context) {
    return ZyCard(
      onTap: () => context.go('/teacher/review'),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Icon(Icons.grading_rounded,
                color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: AppDimens.grid4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '复核批阅结果',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pending 份待处理，AI 已完成初步批阅',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 22, color: AppColors.soft),
        ],
      ),
    );
  }

  Widget _buildWeaknessCard(List<WeaknessItem> weakness) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '班级常错点'),
          const SizedBox(height: AppDimens.grid3),
          ...weakness.map((WeaknessItem w) => _WeaknessRow(item: w)),
        ],
      ),
    );
  }

  Widget _buildCasesCard(List<CaseModel> cases) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZySectionHeader(
            title: '配置新病例',
            actionLabel: '病例广场',
            onAction: () => context.go('/teacher/market'),
          ),
          const SizedBox(height: AppDimens.grid3),
          Container(
            padding: const EdgeInsets.all(AppDimens.grid4),
            decoration: BoxDecoration(
              color: const Color(0x080F766E),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: AppColors.brand),
                const SizedBox(width: AppDimens.grid3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '创建一个新的 SP 病例',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前已有 ${cases.length} 个训练病例',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeaknessRow extends StatelessWidget {
  const _WeaknessRow({required this.item});

  final WeaknessItem item;

  @override
  Widget build(BuildContext context) {
    final int percent = (item.avg * 100).round();
    final Color color = percent < 55
        ? AppColors.danger
        : percent < 65
            ? AppColors.warning
            : AppColors.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              item.tag,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            flex: 3,
            child: Stack(
              children: <Widget>[
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0x140F766E),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: item.avg,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          SizedBox(
            width: 80,
            child: Text(
              '$percent% · ${item.count} 次',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
