import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'package:zhiyu/data/models.dart';
import 'review_detail_sheet.dart';

/// 教师批阅队列：紧凑行 + 可拖动详情层
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  static const List<String> _filters = <String>[
    '全部',
    '待复核',
    '已初步批阅',
    '有争议项',
  ];

  late List<ReviewItem> _queue;
  String _filter = '全部';

  @override
  void initState() {
    super.initState();
    _queue = ref.read(teachingRepositoryProvider).reviewQueue().toList();
  }

  void _openDetail(ReviewItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) => ReviewDetailSheet(
        item: item,
        onApprove: () => _handleApprove(item),
        onReturn: () => _handleReturn(item),
      ),
    );
  }

  void _handleApprove(ReviewItem item) {
    Navigator.of(context).pop();
    setState(() {
      final int index = _queue.indexWhere((ReviewItem q) => q.id == item.id);
      if (index >= 0) {
        _queue[index] = ReviewItem(
          id: item.id,
          student: item.student,
          assignment: item.assignment,
          score: item.score,
          issue: item.issue,
          status: '已复核',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('复核结果已提交')),
    );
  }

  void _handleReturn(ReviewItem item) {
    Navigator.of(context).pop();
    setState(() {
      final int index = _queue.indexWhere((ReviewItem q) => q.id == item.id);
      if (index >= 0) {
        _queue[index] = ReviewItem(
          id: item.id,
          student: item.student,
          assignment: item.assignment,
          score: item.score,
          issue: item.issue,
          status: '待修改',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退回修改')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pending =
        _queue.where((ReviewItem q) => q.status == '待复核').length;
    final int disputed =
        _queue.where((ReviewItem q) => q.status == '有争议项').length;
    final String summary =
        disputed > 0 ? '待复核 $pending 项，其中 $disputed 项有争议' : '待复核 $pending 项';
    final List<ReviewItem> visible = _filter == '全部'
        ? _queue
        : _queue.where((ReviewItem q) => q.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ZyPageHead(
              kicker: '批阅复核',
              title: 'AI 批阅队列',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, 0,
                  AppDimens.pagePadding, AppDimens.grid3),
              child: Text(summary, style: AppTextStyles.body),
            ),
          ),
          SliverToBoxAdapter(
            child: _UnderlineFilter(
              options: _filters,
              value: _filter,
              onChanged: (String value) => setState(() => _filter = value),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding, 0, AppDimens.pagePadding, 120),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (BuildContext _, int __) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (BuildContext _, int index) => _ReviewRow(
                item: visible[index],
                onTap: () => _openDetail(visible[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlineFilter extends StatelessWidget {
  const _UnderlineFilter({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
        itemCount: options.length,
        separatorBuilder: (BuildContext _, int __) =>
            const SizedBox(width: AppDimens.grid4),
        itemBuilder: (BuildContext _, int index) {
          final String option = options[index];
          final bool active = option == value;
          return InkWell(
            onTap: () => onChanged(option),
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: AppDimens.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.grid2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.brand : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.brand : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onTap});

  final ReviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.grid4),
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
                      Text(item.student, style: AppTextStyles.title),
                      const SizedBox(height: 4),
                      Text(
                        '${item.assignment} · AI 评分 ${item.score}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                ZyChip(item.status, tone: _statusTone(item.status)),
              ],
            ),
            const SizedBox(height: AppDimens.grid2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.issue,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimens.grid2),
                Text(
                  '复核',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      case '待修改':
        return ZyChipTone.neutral;
      default:
        return ZyChipTone.neutral;
    }
  }
}
