import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师概览：以风险顺序组织今天需要处理的教学记录。
class TeacherOverviewPage extends ConsumerWidget {
  const TeacherOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeachingRepository teachingRepo =
        ref.watch(teachingRepositoryProvider);
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);

    final List<AssignmentModel> assignments = teachingRepo.assignments();
    final List<ReviewItem> reviewQueue =
        _orderedReviewQueue(teachingRepo.reviewQueue());
    final List<WeaknessItem> weakness = teachingRepo.weakness();
    final List<CaseModel> cases = caseRepo.all();

    final int pending =
        reviewQueue.where((ReviewItem item) => item.status == '待复核').length;
    final int disputed =
        reviewQueue.where((ReviewItem item) => item.status == '有争议项').length;
    final int submitted = assignments.fold<int>(
      0,
      (int total, AssignmentModel item) => total + item.submitted,
    );
    final int assigned = assignments.fold<int>(
      0,
      (int total, AssignmentModel item) => total + item.total,
    );
    final int completionRate =
        assigned == 0 ? 0 : (submitted / assigned * 100).round();
    final ReviewItem? topRisk = _firstActionable(reviewQueue);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '今天需要处理的事',
              identityLabel: '教师工作台',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid2,
                AppDimens.pagePadding,
                0,
              ),
              child: _OverviewStatBand(
                pending: pending,
                disputed: disputed,
                completionRate: completionRate,
              ),
            ),
          ),
          if (topRisk != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  AppDimens.grid4,
                  AppDimens.pagePadding,
                  0,
                ),
                child: FilledButton.icon(
                  onPressed: () => context.go('/teacher/review'),
                  icon: const Icon(Icons.fact_check_outlined, size: 20),
                  label: const Text('处理最高风险记录'),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid6,
                AppDimens.pagePadding,
                0,
              ),
              child: _ReviewRegister(
                items: reviewQueue,
                onOpen: () => context.go('/teacher/review'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid6,
                AppDimens.pagePadding,
                0,
              ),
              child: _AssignmentProgress(assignments: assignments),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid6,
                AppDimens.pagePadding,
                0,
              ),
              child: _WeaknessList(items: weakness),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid6,
                AppDimens.pagePadding,
                0,
              ),
              child: _CaseShortcuts(
                caseCount: cases.length,
                onCases: () => context.go('/teacher/cases'),
                onMarket: () => context.push('/teacher/market'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}

class _OverviewStatBand extends StatelessWidget {
  const _OverviewStatBand({
    required this.pending,
    required this.disputed,
    required this.completionRate,
  });

  final int pending;
  final int disputed;
  final int completionRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('teacher-overview-stat-band'),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.ruleStrong),
          bottom: BorderSide(color: AppColors.ruleStrong),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCell(
              label: '待复核',
              value: '$pending',
              valueColor: AppColors.action,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: '风险争议',
              value: '$disputed',
              valueColor: AppColors.risk,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatCell(
              label: '班级完成率',
              value: '$completionRate%',
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.data),
        const SizedBox(height: AppDimens.grid),
        Text(
          value,
          style: AppTextStyles.title.copyWith(
            color: valueColor,
            fontFeatures: AppTextStyles.data.fontFeatures,
          ),
        ),
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
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.grid3),
      color: AppColors.rule,
    );
  }
}

class _ReviewRegister extends StatelessWidget {
  const _ReviewRegister({required this.items, required this.onOpen});

  final List<ReviewItem> items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('teacher-review-register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(
          title: '批阅登记',
          description: '争议项优先，同状态按原登记顺序',
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
            child: Text('当前没有待处理记录', style: AppTextStyles.caption),
          )
        else
          ...List<Widget>.generate(items.length, (int index) {
            final ReviewItem item = items[index];
            return ClinicalRecordRow(
              leadingLabel: '${item.score} 分',
              title: '${item.student} · ${item.assignment}',
              subtitle: item.issue,
              statusLabel: item.status,
              statusTone: _reviewTone(item.status),
              onTap: onOpen,
              showDivider: index != items.length - 1,
            );
          }),
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
        const ClinicalSectionHeader(title: '作业进度'),
        ...assignments.map(
          (AssignmentModel item) => ClinicalRecordRow(
            leadingLabel: item.due,
            title: item.title,
            subtitle: '${item.className} · 提交 ${item.submitted}/${item.total}',
            statusLabel: item.status,
            statusTone: _assignmentTone(item.status),
          ),
        ),
      ],
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
        const ClinicalSectionHeader(title: '班级薄弱点'),
        ...items.map((WeaknessItem item) {
          final int percent = (item.avg * 100).round();
          return ClinicalRecordRow(
            leadingLabel: '$percent%',
            title: item.tag,
            subtitle: '${item.count} 次训练记录',
            statusLabel: percent < 55 ? '需关注' : '继续跟进',
            statusTone: percent < 55
                ? ClinicalEvidenceTone.risk
                : ClinicalEvidenceTone.action,
          );
        }),
      ],
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
        const ClinicalSectionHeader(title: '病例建设'),
        ClinicalRecordRow(
          leadingLabel: '病例',
          title: '管理训练病例',
          subtitle: '当前已有 $caseCount 个训练病例',
          statusLabel: '管理',
          statusTone: ClinicalEvidenceTone.action,
          onTap: onCases,
        ),
        ClinicalRecordRow(
          leadingLabel: '共享',
          title: '病例广场',
          subtitle: '引用共享病例',
          statusLabel: '引用',
          statusTone: ClinicalEvidenceTone.action,
          onTap: onMarket,
          showDivider: false,
        ),
      ],
    );
  }
}

List<ReviewItem> _orderedReviewQueue(Iterable<ReviewItem> items) {
  final List<ReviewItem> source = items.toList(growable: false);
  return <ReviewItem>[
    ...source.where((ReviewItem item) => item.status == '有争议项'),
    ...source.where((ReviewItem item) => item.status == '待复核'),
    ...source.where(
      (ReviewItem item) => item.status != '有争议项' && item.status != '待复核',
    ),
  ];
}

ReviewItem? _firstActionable(Iterable<ReviewItem> items) {
  for (final ReviewItem item in items) {
    if (item.status != '已复核') return item;
  }
  return null;
}

ClinicalEvidenceTone _reviewTone(String status) {
  switch (status) {
    case '有争议项':
    case '待修改':
      return ClinicalEvidenceTone.risk;
    case '待复核':
      return ClinicalEvidenceTone.action;
    case '已复核':
      return ClinicalEvidenceTone.success;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}

ClinicalEvidenceTone _assignmentTone(String status) {
  switch (status) {
    case '待复核':
      return ClinicalEvidenceTone.risk;
    case '进行中':
    case 'AI 批阅中':
      return ClinicalEvidenceTone.action;
    case '已完成':
      return ClinicalEvidenceTone.success;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}
