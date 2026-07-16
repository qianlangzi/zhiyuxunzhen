import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 教师概览：今日教学待办
class TeacherOverviewPage extends ConsumerWidget {
  const TeacherOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeachingRepository teachingRepo =
        ref.watch(teachingRepositoryProvider);
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);

    final List<AssignmentModel> assignments = teachingRepo.assignments();
    final List<ReviewItem> reviewQueue = teachingRepo.reviewQueue();
    final List<WeaknessItem> weakness = teachingRepo.weakness();
    final List<CaseModel> cases = caseRepo.all();

    final int pending =
        reviewQueue.where((ReviewItem item) => item.status != '已复核').length;
    final int disputed =
        reviewQueue.where((ReviewItem item) => item.status == '有争议项').length;
    ReviewItem? topPending;
    for (final ReviewItem item in reviewQueue) {
      if (item.status != '已复核') {
        topPending = item;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '教学概览',
              title: '今天需要处理',
              subtitle: '优先确认争议批阅，再查看作业进度。',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: _PriorityActions(
                pendingCount: pending,
                disputedCount: disputed,
                topPending: topPending,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _AssignmentProgress(assignments: assignments),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid5)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _WeaknessList(items: weakness),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid5)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _CaseShortcuts(
                caseCount: cases.length,
                onCases: () => context.go('/teacher/cases'),
                onMarket: () => context.go('/teacher/market'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}

class _PriorityActions extends StatelessWidget {
  const _PriorityActions({
    required this.pendingCount,
    required this.disputedCount,
    required this.topPending,
  });

  final int pendingCount;
  final int disputedCount;
  final ReviewItem? topPending;

  @override
  Widget build(BuildContext context) {
    final ReviewItem? top = topPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (top != null) ...<Widget>[
          ZyCard(
            onTap: () => context.go('/teacher/review'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ZyChip(top.status, tone: ZyChipTone.warning),
                    const Spacer(),
                    Text('${top.score} 分', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppDimens.grid3),
                Text(top.student, style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(top.assignment, style: AppTextStyles.caption),
                const SizedBox(height: AppDimens.grid2),
                Text(top.issue, style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.grid3),
        ],
        ZyListTile(
          leading: const Icon(Icons.grading_rounded,
              size: 20, color: AppColors.brand),
          title: '待复核 $pendingCount 项',
          subtitle: disputedCount > 0 ? '其中 $disputedCount 项有争议' : '优先确认批阅结果',
          onTap: () => context.go('/teacher/review'),
        ),
        ZyListTile(
          leading: const Icon(Icons.edit_note_rounded,
              size: 20, color: AppColors.brand),
          title: '配置新病例',
          subtitle: '为下一轮训练做准备',
          onTap: () => context.go('/teacher/cases'),
          showDivider: false,
        ),
      ],
    );
  }
}

class _AssignmentProgress extends StatelessWidget {
  const _AssignmentProgress({required this.assignments});

  final List<AssignmentModel> assignments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZySectionHeader(title: '作业进度'),
        const SizedBox(height: AppDimens.grid3),
        ...assignments.map((AssignmentModel a) => _AssignmentRow(item: a)),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.item});

  final AssignmentModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${item.title} · ${item.className}',
                    style: AppTextStyles.bodyStrong),
              ),
              Text('${item.submitted}/${item.total}',
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: AppColors.brandSoft,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 2),
          Text('${item.due} · ${item.status}', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _WeaknessList extends StatelessWidget {
  const _WeaknessList({required this.items});

  final List<WeaknessItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZySectionHeader(title: '班级薄弱点'),
        const SizedBox(height: AppDimens.grid3),
        ...items.map((WeaknessItem item) => _WeaknessRow(item: item)),
      ],
    );
  }
}

class _WeaknessRow extends StatelessWidget {
  const _WeaknessRow({required this.item});

  final WeaknessItem item;

  @override
  Widget build(BuildContext context) {
    final int percent = (item.avg * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(item.tag, style: AppTextStyles.bodyStrong),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item.avg,
                minHeight: 6,
                backgroundColor: AppColors.brandSoft,
                color: percent < 55 ? AppColors.danger : AppColors.brand,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          SizedBox(
            width: 72,
            child: Text('$percent% · ${item.count} 次',
                textAlign: TextAlign.right, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}

class _CaseShortcuts extends StatelessWidget {
  const _CaseShortcuts({
    required this.caseCount,
    required this.onCases,
    required this.onMarket,
  });

  final int caseCount;
  final VoidCallback onCases;
  final VoidCallback onMarket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZySectionHeader(title: '病例建设'),
        ZyListTile(
          leading: const Icon(Icons.edit_note_rounded,
              size: 20, color: AppColors.brand),
          title: '管理训练病例',
          subtitle: '当前已有 $caseCount 个训练病例',
          onTap: onCases,
        ),
        ZyListTile(
          leading: const Icon(Icons.travel_explore_rounded,
              size: 20, color: AppColors.brand),
          title: '病例广场',
          subtitle: '引用共享病例',
          onTap: onMarket,
          showDivider: false,
        ),
      ],
    );
  }
}
