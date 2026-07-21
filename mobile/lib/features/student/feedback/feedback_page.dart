import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/config/app_config.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 能力反馈：先给出可执行结论，再列出评分证据和训练顺序。
class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LearningOverview> overviewState =
        ref.watch(learningOverviewProvider);
    if (overviewState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (overviewState.hasError) {
      return Scaffold(
        body: ZyErrorState(
          title: '能力反馈加载失败',
          message: overviewState.error.toString(),
          actionLabel: '重试',
          onRetry: () => ref.invalidate(learningOverviewProvider),
        ),
      );
    }
    final List<AbilityScore> abilities =
        overviewState.value?.abilities ?? const <AbilityScore>[];
    final AbilityScore? lowest = _weakestAbility(abilities);
    final List<LearningPathItem> path = AppConfig.mockEnabled
        ? ref.read(learningRepositoryProvider).learningPath()
        : lowest == null
            ? const <LearningPathItem>[]
            : <LearningPathItem>[
                LearningPathItem(
                  title: '针对「${lowest.label}」继续病例训练',
                  meta: '依据真实 OSCE 评分中的最低维度生成',
                  progress: lowest.value,
                ),
              ];
    final int average = abilities.isEmpty
        ? 0
        : (abilities.fold<int>(
                  0,
                  (int total, AbilityScore item) => total + item.value,
                ) /
                abilities.length)
            .round();
    final AbilityScore? weakest = _weakestAbility(abilities);
    final LearningPathItem? firstStep = path.isEmpty ? null : path.first;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '能力反馈',
              identityLabel: '学生工作台',
            ),
          ),
          SliverToBoxAdapter(
            child: _ActionConclusion(
              average: average,
              weakest: weakest,
              firstStep: firstStep,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ClinicalSectionHeader(
                    title: '能力证据',
                    description: '本次问诊按 100 分制记录；状态由分数区间直接生成。',
                  ),
                  if (abilities.isEmpty)
                    const _InlineEmpty(message: '完成一次问诊后显示能力证据。')
                  else
                    ...abilities.map(
                      (AbilityScore item) => _AbilityEvidenceRow(item: item),
                    ),
                ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ClinicalSectionHeader(
                    title: '下一步建议',
                    description: '按记录顺序继续训练，首项可直接进入病例库。',
                  ),
                  if (path.isEmpty)
                    const _InlineEmpty(message: '当前没有待执行的训练建议。')
                  else
                    ...path.asMap().entries.map(
                          (MapEntry<int, LearningPathItem> entry) =>
                              ClinicalRecordRow(
                            leadingLabel:
                                (entry.key + 1).toString().padLeft(2, '0'),
                            title: entry.value.title,
                            subtitle: entry.value.meta,
                            statusLabel: '${entry.value.progress}%',
                            statusTone: entry.key == 0
                                ? ClinicalEvidenceTone.action
                                : ClinicalEvidenceTone.neutral,
                            onTap: entry.key == 0
                                ? () => context.push('/student/cases')
                                : null,
                            showDivider: entry.key != path.length - 1,
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.grid8 + AppDimens.grid4),
          ),
        ],
      ),
    );
  }

  static AbilityScore? _weakestAbility(List<AbilityScore> abilities) {
    if (abilities.isEmpty) return null;
    return abilities.reduce(
      (AbilityScore current, AbilityScore next) =>
          next.value < current.value ? next : current,
    );
  }
}

class _ActionConclusion extends StatelessWidget {
  const _ActionConclusion({
    required this.average,
    required this.weakest,
    required this.firstStep,
  });

  final int average;
  final AbilityScore? weakest;
  final LearningPathItem? firstStep;

  @override
  Widget build(BuildContext context) {
    final String conclusion = weakest == null || firstStep == null
        ? '先完成一例完整问诊，再根据证据安排下一轮训练。'
        : '下一轮先补强${weakest!.label}：完成「${firstStep!.title}」。';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.grid3,
        AppDimens.pagePadding,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.ink, width: 1),
            bottom: BorderSide(color: AppColors.rule, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '本次表现',
                    style: AppTextStyles.data.copyWith(color: AppColors.action),
                  ),
                ),
                Text(
                  '$average / 100',
                  style: AppTextStyles.data.copyWith(color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.grid2),
            Semantics(
              liveRegion: true,
              label: '行动结论，$conclusion',
              child: ExcludeSemantics(
                child: Text(conclusion, style: AppTextStyles.h3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityEvidenceRow extends StatelessWidget {
  const _AbilityEvidenceRow({required this.item});

  final AbilityScore item;

  @override
  Widget build(BuildContext context) {
    final _AbilityState state = _abilityState(item.value);
    return Semantics(
      container: true,
      label: '${item.label}，${item.value} 分，${state.label}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.rule, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(item.label, style: AppTextStyles.bodyStrong),
                  ),
                  Text(
                    state.label,
                    style: AppTextStyles.data.copyWith(color: state.color),
                  ),
                  const SizedBox(width: AppDimens.grid3),
                  Text(
                    '${item.value} / 100',
                    style: AppTextStyles.data.copyWith(color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.grid2),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusStatus),
                child: LinearProgressIndicator(
                  value: item.value / 100,
                  minHeight: AppDimens.grid,
                  backgroundColor: AppColors.paperStrong,
                  color: state.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _AbilityState _abilityState(int value) {
    if (value >= 85) {
      return const _AbilityState('优势', AppColors.success);
    }
    if (value >= 75) {
      return const _AbilityState('稳定', AppColors.action);
    }
    if (value >= 60) {
      return const _AbilityState('待补强', AppColors.warning);
    }
    return const _AbilityState('重点复习', AppColors.risk);
  }
}

class _AbilityState {
  const _AbilityState(this.label, this.color);

  final String label;
  final Color color;
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
