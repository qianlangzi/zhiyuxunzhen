import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';
import 'review_detail_sheet.dart';

/// 教师批阅登记：按争议、待复核、其他状态稳定排序。
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  static const List<String> _filters = <String>[
    '全部',
    '有争议项',
    '待复核',
    '已初步批阅',
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
    setState(() => _replaceStatus(item, '已复核'));
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('复核结果已提交')),
    );
  }

  void _handleReturn(ReviewItem item) {
    Navigator.of(context).pop();
    setState(() => _replaceStatus(item, '待修改'));
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('已退回修改')),
    );
  }

  void _replaceStatus(ReviewItem item, String status) {
    final int index = _queue.indexWhere((ReviewItem row) => row.id == item.id);
    if (index < 0) return;
    _queue[index] = ReviewItem(
      id: item.id,
      student: item.student,
      assignment: item.assignment,
      score: item.score,
      issue: item.issue,
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pending =
        _queue.where((ReviewItem item) => item.status == '待复核').length;
    final int disputed =
        _queue.where((ReviewItem item) => item.status == '有争议项').length;
    final List<ReviewItem> ordered = _orderedReviewQueue(_queue);
    final List<ReviewItem> visible = _filter == '全部'
        ? ordered
        : ordered
            .where((ReviewItem item) => item.status == _filter)
            .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '批阅登记',
              identityLabel: '教师工作台',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid3,
              ),
              child: _QueueSummary(pending: pending, disputed: disputed),
            ),
          ),
          SliverToBoxAdapter(
            child: _UnderlineFilter(
              options: _filters,
              value: _filter,
              onChanged: (String value) => setState(() => _filter = value),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.grid3,
                AppDimens.pagePadding,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ClinicalSectionHeader(
                    title: '记录队列',
                    description: '争议项优先，同状态按原登记顺序',
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.grid6,
                      ),
                      child: Text(
                        '当前筛选条件下没有记录',
                        style: AppTextStyles.caption,
                      ),
                    )
                  else
                    ...List<Widget>.generate(visible.length, (int index) {
                      final ReviewItem item = visible[index];
                      return ClinicalRecordRow(
                        leadingLabel: '${item.score} 分',
                        title: '${item.student} · ${item.assignment}',
                        subtitle: item.issue,
                        statusLabel: item.status,
                        statusTone: _reviewTone(item.status),
                        onTap: () => _openDetail(item),
                        showDivider: index != visible.length - 1,
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.pending, required this.disputed});

  final int pending;
  final int disputed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid2),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.rule),
          bottom: BorderSide(color: AppColors.rule),
        ),
      ),
      child: Wrap(
        spacing: AppDimens.grid4,
        runSpacing: AppDimens.grid,
        children: <Widget>[
          Text('待复核 $pending', style: AppTextStyles.data),
          Text(
            '风险争议 $disputed',
            style: AppTextStyles.data.copyWith(color: AppColors.risk),
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
          return Semantics(
            button: true,
            selected: active,
            label: '筛选：$option',
            child: InkWell(
              onTap: () => onChanged(option),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppDimens.touchTarget,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.grid2,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.action : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  option,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.action : AppColors.graphite,
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

List<ReviewItem> _orderedReviewQueue(Iterable<ReviewItem> items) {
  final List<ReviewItem> source = items.toList(growable: false);
  return <ReviewItem>[
    ...source.where((ReviewItem item) => item.status == '有争议项'),
    ...source.where((ReviewItem item) => item.status == '待复核'),
    ...source.where(
      (ReviewItem item) => item.status != '有争议项' && item.status != '待复核',
    ),
  ];
}

ClinicalEvidenceTone _reviewTone(String status) {
  switch (status) {
    case '有争议项':
    case '待修改':
      return ClinicalEvidenceTone.risk;
    case '待复核':
      return ClinicalEvidenceTone.action;
    case '已复核':
      return ClinicalEvidenceTone.success;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}
