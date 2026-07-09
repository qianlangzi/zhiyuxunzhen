import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 病例广场
class CaseMarketPage extends ConsumerWidget {
  const CaseMarketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository repo = ref.watch(caseRepositoryProvider);
    final List<MarketCaseModel> cases = repo.market();

    return Scaffold(
      appBar: const ZyAppBar(title: Text('病例广场'), transparent: true),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0,
                  AppDimens.pagePadding, AppDimens.grid3),
              child: _buildSearchBar(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding, vertical: AppDimens.grid2),
            sliver: SliverList.separated(
              itemCount: cases.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(height: AppDimens.grid3),
              itemBuilder: (BuildContext context, int index) =>
                  _MarketCard(item: cases[index]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.grid8)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.grid3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded,
              size: 20, color: AppColors.soft),
          const SizedBox(width: AppDimens.grid2),
          const Expanded(
            child: Text(
              '搜索科室、作者或关键词',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.soft,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: const Icon(Icons.tune_rounded,
                size: 16, color: AppColors.brandStrong),
          ),
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.item});

  final MarketCaseModel item;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.author} · ${item.department}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.certified)
                const Icon(Icons.verified_rounded,
                    size: 18, color: AppColors.aqua),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Row(
            children: <Widget>[
              ZyChip(Formatters.difficultyLabel(item.difficulty),
                  tone: ZyChipTone.warning),
              const SizedBox(width: 6),
              ZyChip('${item.referenceCount} 引用', tone: ZyChipTone.neutral),
              const Spacer(),
              const Icon(Icons.star_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 2),
              Text(
                item.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('预览'),
                ),
              ),
              const SizedBox(width: AppDimens.grid2),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('引用到我的班'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}