import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';

/// 错题页
class MistakesPage extends ConsumerStatefulWidget {
  const MistakesPage({super.key});

  @override
  ConsumerState<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends ConsumerState<MistakesPage> {
  String _filter = '全部'; // 全部 / 未复习 / 已复习

  @override
  Widget build(BuildContext context) {
    final LearningRepository repo = ref.watch(learningRepositoryProvider);
    List<MistakeItem> mistakes = repo.mistakes();
    if (_filter == '未复习') {
      mistakes = mistakes.where((MistakeItem m) => !m.reviewed).toList();
    } else if (_filter == '已复习') {
      mistakes = mistakes.where((MistakeItem m) => m.reviewed).toList();
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildFilter()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding,
                AppDimens.grid3, AppDimens.pagePadding, AppDimens.grid8),
            sliver: mistakes.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppDimens.grid10),
                      child: ZyEmptyState(
                        icon: Icons.check_circle_outline_rounded,
                        title: '当前分类下无错题',
                        detail: '继续训练，保持手感',
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: mistakes.length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(height: AppDimens.grid3),
                    itemBuilder: (BuildContext context, int index) =>
                        _MistakeCard(item: mistakes[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const ZyPageHead(
      kicker: '错题复盘',
      title: '出错场景与改进线索',
    );
  }

  Widget _buildFilter() {
    final List<String> filters = <String>['全部', '未复习', '已复习'];
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

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.item});

  final MistakeItem item;

  @override
  Widget build(BuildContext context) {
    return ZyCard(
      padding: const EdgeInsets.all(AppDimens.cardPaddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ZyChip(item.type,
                  tone: item.type.contains('错误')
                      ? ZyChipTone.danger
                      : ZyChipTone.warning),
              const SizedBox(width: 6),
              ZyChip(item.tag, tone: ZyChipTone.neutral),
              const Spacer(),
              ZyChip(
                item.reviewed ? '已复习' : '未复习',
                tone: item.reviewed ? ZyChipTone.success : ZyChipTone.brand,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid3),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppDimens.grid2),
          Container(
            padding: const EdgeInsets.all(AppDimens.grid3),
            decoration: BoxDecoration(
              color: const Color(0x080F766E),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: AppColors.line, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: AppDimens.grid2),
                Expanded(
                  child: Text(
                    item.evidence,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.history_edu_rounded, size: 18),
                  label: const Text('回到对应病例'),
                ),
              ),
              const SizedBox(width: AppDimens.grid2),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('标记已复习'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}