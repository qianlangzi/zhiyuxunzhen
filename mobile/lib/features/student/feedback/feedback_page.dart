import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 能力反馈：结论、维度与下一步建议
class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearningRepository repo = ref.watch(learningRepositoryProvider);
    final List<AbilityScore> abilities = repo.abilities();
    final List<LearningPathItem> path = repo.learningPath();
    final int avg = abilities.isEmpty
        ? 0
        : (abilities.fold<int>(0, (int p, AbilityScore a) => p + a.value) /
                abilities.length)
            .round();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ZyPageHead(kicker: '反馈', title: '能力反馈'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: _ConclusionCard(avg: avg),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _AbilitiesCard(abilities: abilities),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _SuggestionsCard(path: path),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.grid4)),
        ],
      ),
    );
  }
}

class _ConclusionCard extends StatelessWidget {
  const _ConclusionCard({required this.avg});

  final int avg;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('本次表现', style: AppTextStyles.title),
              const Spacer(),
              Text('$avg/100',
                  style: AppTextStyles.h3.copyWith(color: AppColors.brand)),
            ],
          ),
          const SizedBox(height: AppDimens.grid2),
          Text(_conclusionFor(avg), style: AppTextStyles.body),
        ],
      ),
    );
  }

  String _conclusionFor(int v) {
    if (v >= 85) return '整体表现优秀，继续保持当前训练节奏。';
    if (v >= 75) return '表现稳定，诊断逻辑仍有提升空间。';
    if (v >= 60) return '基础尚可，建议加强诊断逻辑与检查选择训练。';
    return '需要系统复习并重点突破薄弱环节。';
  }
}

class _AbilitiesCard extends StatelessWidget {
  const _AbilitiesCard({required this.abilities});

  final List<AbilityScore> abilities;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '能力维度'),
          const SizedBox(height: AppDimens.grid4),
          ...abilities.map((AbilityScore a) => _AbilityRow(item: a)),
        ],
      ),
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.item});

  final AbilityScore item;

  @override
  Widget build(BuildContext context) {
    final Color color = _colorFor(item.value);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.grid3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(item.label, style: AppTextStyles.bodyStrong),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item.value / 100,
                minHeight: 6,
                backgroundColor: AppColors.brandSoft,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          SizedBox(
            width: 36,
            child: Text(
              '${item.value}',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(int v) {
    if (v >= 85) return AppColors.success;
    if (v >= 70) return AppColors.brand;
    if (v >= 60) return AppColors.warning;
    return AppColors.danger;
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.path});

  final List<LearningPathItem> path;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: '下一步建议'),
          const SizedBox(height: AppDimens.grid3),
          ...path.asMap().entries.map((MapEntry<int, LearningPathItem> e) {
            // 仅第一项可路由到病例列表；其余作为信息呈现，避免死按钮
            final bool routed = e.key == 0;
            return _SuggestionRow(item: e.value, routed: routed);
          }),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.item, required this.routed});

  final LearningPathItem item;
  final bool routed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: routed ? () => context.push('/student/cases') : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppDimens.grid3, horizontal: AppDimens.grid2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 4),
                    Text(item.meta, style: AppTextStyles.caption),
                    const SizedBox(height: AppDimens.grid2),
                    ZyProgress(value: item.progress / 100, height: 6),
                  ],
                ),
              ),
              if (routed) ...<Widget>[
                const SizedBox(width: AppDimens.grid2),
                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: AppColors.soft),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
