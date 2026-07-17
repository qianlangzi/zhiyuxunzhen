import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../shared/widgets/widgets.dart';
import 'training_activity.dart';

class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key});

  @override
  ConsumerState<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  String? _emptyDayNotice;

  @override
  Widget build(BuildContext context) {
    final UserModel? user = ref.watch(authControllerProvider).user;
    final List<HeatmapDay> days =
        ref.watch(learningRepositoryProvider).heatmap();
    final DateTime now = DateTime.now();
    final TrainingActivitySummary summary =
        TrainingActivitySummary.fromDays(days, endDate: now);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '${user?.displayName ?? '同学'}的学习记录',
              identityLabel: '${user?.orgName ?? '未设置班级'} · 学生',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid2,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              child: _LearningSummary(summary: summary),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              child: _HeatmapSection(
                days: days,
                endDate: now,
                emptyDayNotice: _emptyDayNotice,
                onDayTap: _onDayTap,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              child: const _LearningRecords(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              child: _TeachingNotice(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              child: _AccountSection(ref: ref),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.navBarHeight + AppDimens.grid8),
          ),
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
        padding: const EdgeInsets.fromLTRB(
          AppDimens.pagePadding,
          0,
          AppDimens.pagePadding,
          AppDimens.grid6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClinicalSectionHeader(
              title: day.date,
              description: '完成 ${day.completedCount} 次训练',
            ),
            for (int index = 0; index < day.activities.length; index++)
              ClinicalRecordRow(
                leadingLabel: '${index + 1}',
                title: day.activities[index],
                statusLabel: '已完成',
                statusTone: ClinicalEvidenceTone.success,
                showDivider: index != day.activities.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _LearningSummary extends StatelessWidget {
  const _LearningSummary({required this.summary});

  final TrainingActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(title: '学习概况'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.rule, width: 1),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SummaryValue(
                  label: '训练天数',
                  value: summary.activeDays,
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(
                  label: '连续天数',
                  value: summary.currentStreak,
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(
                  label: '完成次数',
                  value: summary.completedCount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: AppTextStyles.h3.copyWith(color: AppColors.action),
        ),
        const SizedBox(height: AppDimens.grid),
        Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: VerticalDivider(width: 1, color: AppColors.rule),
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
        const ClinicalSectionHeader(
          title: '最近三个月',
          description: '颜色越深，表示当天完成的训练越多。',
        ),
        const SizedBox(height: AppDimens.grid4),
        ZyActivityHeatmap(
          days: days,
          endDate: endDate,
          onDayTap: onDayTap,
        ),
        if (emptyDayNotice != null) ...<Widget>[
          const SizedBox(height: AppDimens.grid2),
          Text(
            emptyDayNotice!,
            style: AppTextStyles.caption.copyWith(color: AppColors.graphite),
          ),
        ],
      ],
    );
  }
}

class _LearningRecords extends StatelessWidget {
  const _LearningRecords();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(title: '学习记录'),
        ClinicalRecordRow(
          leadingLabel: '反馈',
          title: '训练历史',
          subtitle: '查看最近的能力反馈与训练记录',
          statusLabel: '查看',
          statusTone: ClinicalEvidenceTone.action,
          onTap: () => context.go('/student/feedback'),
        ),
        ClinicalRecordRow(
          leadingLabel: '病例',
          title: '收藏与重点练习',
          subtitle: '返回病例库继续临床训练',
          statusLabel: '查看',
          statusTone: ClinicalEvidenceTone.action,
          onTap: () => context.go('/student/cases'),
        ),
      ],
    );
  }
}

class _TeachingNotice extends StatelessWidget {
  const _TeachingNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(title: '使用说明'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.health_and_safety_outlined,
                size: 18,
                color: AppColors.graphite,
              ),
              const SizedBox(width: AppDimens.grid2),
              Expanded(
                child: Text(
                  '本应用仅供医学教学训练使用，不能替代临床判断和真实医疗决策。',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ClinicalSectionHeader(title: '账号'),
        const SizedBox(height: AppDimens.grid4),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.risk,
            side: const BorderSide(color: AppColors.risk, width: 1),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text('退出登录'),
        ),
      ],
    );
  }
}
