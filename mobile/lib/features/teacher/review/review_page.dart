import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

/// 教师批阅页
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final TeachingRepository repo = ref.watch(teachingRepositoryProvider);
    final List<ReviewItem> all = repo.reviewQueue();
    final int pending =
        all.where((ReviewItem r) => r.status == '待复核').length;
    final int disputed =
        all.where((ReviewItem r) => r.status == '有争议项').length;

    List<ReviewItem> queue = all;
    if (_filter != '全部') {
      queue = all.where((ReviewItem r) => r.status == _filter).toList();
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _buildHeader(pending, disputed),
          ),
          SliverToBoxAdapter(
            child: _buildFilter(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding, AppDimens.grid3, AppDimens.pagePadding, AppDimens.grid8),
            sliver: queue.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppDimens.grid10),
                      child: ZyEmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: '当前队列已清空',
                        detail: '稍后会有新的批阅任务',
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: queue.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppDimens.grid3),
                    itemBuilder: (BuildContext context, int index) =>
                        _ReviewCard(item: queue[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int pending, int disputed) {
    return Column(
      children: <Widget>[
        const ZyPageHead(kicker: '批阅', title: 'AI 批阅队列与人工复核'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding, AppDimens.grid3, AppDimens.pagePadding, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ZyStatCard(
                  label: '待复核',
                  value: '$pending',
                  detail: '保留人工最终判断',
                  tone: pending > 0 ? StatTone.warning : StatTone.neutral,
                ),
              ),
              const SizedBox(width: AppDimens.grid3),
              Expanded(
                child: ZyStatCard(
                  label: '争议项',
                  value: '$disputed',
                  detail: '需要人工确认',
                  tone: disputed > 0 ? StatTone.danger : StatTone.neutral,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilter() {
    final List<String> filters = <String>['全部', '待复核', '已初步批阅', '有争议项'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.pagePadding, vertical: 0),
        itemCount: filters.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: AppDimens.grid2),
        itemBuilder: (BuildContext context, int index) {
          final bool active = filters[index] == _filter;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _filter = filters[index]),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.grid4, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  border: Border.all(
                    color: active ? AppColors.brand : AppColors.line,
                    width: 1,
                  ),
                ),
                child: Text(
                  filters[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});

  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final Color scoreColor = item.score >= 85
        ? AppColors.brand
        : item.score >= 70
            ? AppColors.aqua
            : item.score >= 60
                ? AppColors.warning
                : AppColors.danger;

    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded,
                    size: 22, color: AppColors.brand),
              ),
              const SizedBox(width: AppDimens.grid3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.student,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.assignment,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${item.score}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'AI 评分',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.soft,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Container(
            padding: const EdgeInsets.all(AppDimens.grid3),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.flag_outlined,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: AppDimens.grid2),
                Expanded(
                  child: Text(
                    item.issue,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.grid3),
          Row(
            children: <Widget>[
              ZyChip(item.status, tone: _statusTone(item.status)),
              const Spacer(),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('查看'),
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
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('复核'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ZyChipTone _statusTone(String status) {
    switch (status) {
      case '待复核':
        return ZyChipTone.warning;
      case '已初步批阅':
        return ZyChipTone.aqua;
      case '有争议项':
        return ZyChipTone.danger;
      case '已复核':
        return ZyChipTone.success;
      default:
        return ZyChipTone.neutral;
    }
  }
}
