import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

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
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '出错场景与改进线索',
              identityLabel: '学生复盘',
            ),
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
                        const SizedBox(height: AppDimens.grid4),
                    itemBuilder: (BuildContext context, int index) =>
                        _MistakeRecord(item: filtered[index]),
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

class _MistakeRecord extends StatelessWidget {
  const _MistakeRecord({required this.item});

  final MistakeItem item;

  @override
  Widget build(BuildContext context) {
    final bool pending = !item.reviewed;
    final String status = pending ? '待复盘' : '已完成';
    final String nextStep = pending ? '重做病例并补录诊断依据' : '再次训练并核对诊断依据';

    return Semantics(
      container: true,
      label: '复盘记录，${item.title}，$status',
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.ink, width: 1),
            bottom: BorderSide(color: AppColors.rule, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.grid3,
          AppDimens.grid4,
          AppDimens.grid3,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.title, style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.grid3),
            _RecordField(label: '错误依据', value: item.evidence),
            _RecordField(
              label: '来源 / 标签',
              value: '${item.type} · ${item.tag}',
            ),
            _RecordField(
              label: '状态',
              value: status,
              valueColor: pending ? AppColors.risk : AppColors.success,
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/student/cases'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimens.touchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.grid3,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 88,
                          child: Text(
                            '下一步',
                            style: AppTextStyles.data.copyWith(
                              color: AppColors.graphite,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.grid2),
                        Expanded(
                          child: Text(
                            nextStep,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: AppColors.action,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.grid2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.action,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordField extends StatelessWidget {
  const _RecordField({
    required this.label,
    required this.value,
    this.valueColor = AppColors.ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppDimens.touchTarget),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.rule, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTextStyles.data.copyWith(color: AppColors.graphite),
            ),
          ),
          const SizedBox(width: AppDimens.grid2),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
