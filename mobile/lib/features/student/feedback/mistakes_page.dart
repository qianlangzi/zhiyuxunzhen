import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

enum MistakeFilter { all, pending, completed }

/// 错题复盘：状态分段与证据列表
class MistakesPage extends ConsumerStatefulWidget {
  const MistakesPage({super.key});

  @override
  ConsumerState<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends ConsumerState<MistakesPage> {
  MistakeFilter _filter = MistakeFilter.all;

  @override
  Widget build(BuildContext context) {
    final LearningRepository repo = ref.watch(learningRepositoryProvider);
    final List<MistakeItem> all = repo.mistakes();
    final List<MistakeItem> filtered = switch (_filter) {
      MistakeFilter.pending =>
        all.where((MistakeItem m) => !m.reviewed).toList(),
      MistakeFilter.completed =>
        all.where((MistakeItem m) => m.reviewed).toList(),
      MistakeFilter.all => all,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ZyPageHead(kicker: '错题复盘', title: '出错场景与改进线索'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding, vertical: AppDimens.grid3),
              child: ZySegmentedControl<MistakeFilter>(
                value: _filter,
                segments: const <ZySegment<MistakeFilter>>[
                  ZySegment<MistakeFilter>(
                      value: MistakeFilter.all, label: '全部'),
                  ZySegment<MistakeFilter>(
                      value: MistakeFilter.pending, label: '待复盘'),
                  ZySegment<MistakeFilter>(
                      value: MistakeFilter.completed, label: '已完成'),
                ],
                onChanged: (MistakeFilter v) => setState(() => _filter = v),
              ),
            ),
          ),
          filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppDimens.grid10),
                    child: ZyEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: _emptyTitle(_filter),
                      detail: '继续训练，保持手感',
                      actionLabel: '浏览病例',
                      onAction: () => context.push('/student/cases'),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding,
                      AppDimens.grid2, AppDimens.pagePadding, AppDimens.grid8),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppDimens.grid3),
                    itemBuilder: (BuildContext context, int index) =>
                        _MistakeCard(item: filtered[index]),
                  ),
                ),
        ],
      ),
    );
  }

  String _emptyTitle(MistakeFilter f) => switch (f) {
        MistakeFilter.pending => '当前没有待复盘内容',
        MistakeFilter.completed => '当前没有已完成复盘',
        MistakeFilter.all => '当前没有错题记录',
      };
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.item});

  final MistakeItem item;

  @override
  Widget build(BuildContext context) {
    final bool pending = !item.reviewed;
    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZyChip(
                item.type,
                tone: item.type.contains('错误')
                    ? ZyChipTone.danger
                    : ZyChipTone.warning,
              ),
              const SizedBox(width: 6),
              ZyChip(item.tag, tone: ZyChipTone.neutral),
              const Spacer(),
              ZyChip(
                pending ? '未复盘' : '已复盘',
                tone: pending ? ZyChipTone.brand : ZyChipTone.success,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Text(item.title, style: AppTextStyles.title),
          const SizedBox(height: AppDimens.grid2),
          Container(
            padding: const EdgeInsets.all(AppDimens.grid3),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: AppDimens.grid2),
                Expanded(
                  child: Text(item.evidence, style: AppTextStyles.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.grid3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/student/cases'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppDimens.touchTarget),
              ),
              icon: Icon(
                pending ? Icons.history_edu_rounded : Icons.replay_rounded,
                size: 18,
              ),
              label: Text(pending ? '开始复盘' : '再次训练'),
            ),
          ),
        ],
      ),
    );
  }
}
