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

class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? user = ref.watch(authControllerProvider).user;
    final TeachingRepository teaching = ref.watch(teachingRepositoryProvider);
    final CaseRepository cases = ref.watch(caseRepositoryProvider);
    final int assignmentCount = teaching.assignments().length;
    final int caseCount = cases.all().length;
    final int pendingReviewCount = teaching
        .reviewQueue()
        .where((ReviewItem item) => item.status != '已复核')
        .length;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '${user?.displayName ?? '老师'}的教学记录',
              dateLabel:
                  '${user?.orgName ?? '附属一院心内科'} · ${user?.credentialStatus ?? '资质已认证'}',
              identityLabel: '教师',
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
              child: _TeachingSummary(
                assignmentCount: assignmentCount,
                caseCount: caseCount,
                pendingReviewCount: pendingReviewCount,
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
              child: _TeachingRecords(
                assignmentCount: assignmentCount,
                caseCount: caseCount,
                pendingReviewCount: pendingReviewCount,
              ),
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
}

class _TeachingSummary extends StatelessWidget {
  const _TeachingSummary({
    required this.assignmentCount,
    required this.caseCount,
    required this.pendingReviewCount,
  });

  final int assignmentCount;
  final int caseCount;
  final int pendingReviewCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(
          title: '教学概况',
          description: '数据来自当前本地教学仓库。',
        ),
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
                child: _SummaryValue(label: '作业', value: assignmentCount),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(label: '病例', value: caseCount),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryValue(
                  label: '待处理',
                  value: pendingReviewCount,
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

class _TeachingRecords extends StatelessWidget {
  const _TeachingRecords({
    required this.assignmentCount,
    required this.caseCount,
    required this.pendingReviewCount,
  });

  final int assignmentCount;
  final int caseCount;
  final int pendingReviewCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ClinicalSectionHeader(title: '工作入口'),
        ClinicalRecordRow(
          leadingLabel: '班级',
          title: '我的班级',
          subtitle: '$assignmentCount 项作业正在登记',
          statusLabel: '查看',
          statusTone: ClinicalEvidenceTone.action,
          onTap: () => context.go('/teacher/assignments'),
        ),
        ClinicalRecordRow(
          leadingLabel: '病例',
          title: '我的病例',
          subtitle: '$caseCount 个病例可用于教学配置',
          statusLabel: '查看',
          statusTone: ClinicalEvidenceTone.action,
          onTap: () => context.go('/teacher/cases'),
        ),
        ClinicalRecordRow(
          leadingLabel: '概览',
          title: '教学概览',
          subtitle: '$pendingReviewCount 条批阅记录需要处理',
          statusLabel: '查看',
          statusTone: pendingReviewCount > 0
              ? ClinicalEvidenceTone.risk
              : ClinicalEvidenceTone.success,
          onTap: () => context.go('/teacher'),
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
