import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 反馈页：OSCE 四维 + 学习路径
class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearningRepository repo = ref.watch(learningRepositoryProvider);
    final List<AbilityScore> abilities = repo.abilities();
    final List<LearningPathItem> path = repo.learningPath();
    // 综合评分 = OSCE 四维平均分
    final int avg = abilities.isEmpty
        ? 0
        : (abilities.fold<int>(0, (int p, AbilityScore a) => p + a.value) /
                abilities.length)
            .round();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: _buildScoreSummary(avg),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _buildAbilitiesCard(abilities),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid4)),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: _LearningPathCard(path: path),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.grid8 + AppDimens.grid4)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const ZyPageHead(
      kicker: '反馈',
      title: '最近一次训练反馈',
    );
  }

  Widget _buildScoreSummary(int avg) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.grid5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brand, AppColors.brandStrong],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        boxShadow: AppColors.shadow,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '综合评分',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xB3FFFFFF),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppDimens.grid2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '$avg',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.grid2),
                const Text(
                  '诊断逻辑还有提升空间',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x55FFFFFF), width: 6),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.trending_up_rounded,
                size: 36, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAbilitiesCard(List<AbilityScore> abilities) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ZySectionHeader(title: 'OSCE 四维'),
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
      padding: const EdgeInsets.only(bottom: AppDimens.grid4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Stack(
              children: <Widget>[
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0x140F766E),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: item.value / 100,
                  child: Container(
                    height: 8,
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
            width: 32,
            child: Text(
              '${item.value}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(int v) {
    if (v >= 85) return AppColors.brand;
    if (v >= 70) return AppColors.aqua;
    if (v >= 60) return AppColors.warning;
    return AppColors.danger;
  }
}

class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard({required this.path});

  final List<LearningPathItem> path;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZySectionHeader(
            title: '学习路径',
            actionLabel: '查看错题',
            onAction: () => context.go('/student/mistakes'),
          ),
          const SizedBox(height: AppDimens.grid4),
          ...path.map((LearningPathItem p) => _LearningPathRow(item: p)),
        ],
      ),
    );
  }
}

class _LearningPathRow extends StatelessWidget {
  const _LearningPathRow({required this.item});

  final LearningPathItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.grid3),
      padding: const EdgeInsets.all(AppDimens.grid3),
      decoration: BoxDecoration(
        color: const Color(0x080F766E),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.school_rounded,
                size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: AppDimens.grid3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.meta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppDimens.grid2),
                ZyProgress(value: item.progress / 100, height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
