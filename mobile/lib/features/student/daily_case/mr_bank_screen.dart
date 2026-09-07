import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../student/data/student_service.dart';

/// 每日病历 · 病历题库（往期每日一例，LeetCode 题库风格）
///
/// 按日期倒序列出所有已发布的往期病例，可按「全部/未做/已做」筛选；
/// 已做的显示我的得分，点击进入报告；未做的点击进入工坊补写。
class MrBankScreen extends ConsumerStatefulWidget {
  const MrBankScreen({super.key});

  @override
  ConsumerState<MrBankScreen> createState() => _MrBankScreenState();
}

class _MrBankScreenState extends ConsumerState<MrBankScreen> {
  static const _filters = [
    (label: '全部', value: null),
    (label: '未完成', value: 0),
    (label: '已完成', value: 1),
  ];

  int _filterIndex = 0;
  bool _loading = true;
  final List<Map<String, dynamic>> _items = [];
  int _pageNum = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >
              _scrollCtrl.position.maxScrollExtent - 400 &&
          _hasMore &&
          !_loadingMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  int? get _done => _filters[_filterIndex].value;

  Future<void> _refresh() async {
    setState(() {
      _loading = _items.isEmpty;
      _pageNum = 1;
      _hasMore = true;
    });
    final list = await StudentService().getDailyMrBank(pageNum: 1, done: _done);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(list.whereType<Map<String, dynamic>>());
      _hasMore = list.length >= 20;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final list = await StudentService()
        .getDailyMrBank(pageNum: _pageNum + 1, done: _done);
    if (!mounted) return;
    setState(() {
      _pageNum += 1;
      _items.addAll(list.whereType<Map<String, dynamic>>());
      _hasMore = list.length >= 20;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(
              title: '病历题库',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(RouteNames.studentHome);
                }
              },
            ),
            _buildFilterBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < _filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            AppPressable(
              onTap: () {
                if (_filterIndex == i) return;
                setState(() => _filterIndex = i);
                _refresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filterIndex == i
                      ? AppColors.primaryOf(context)
                      : AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.ruleOf(context), width: 0.5),
                ),
                child: Text(
                  _filters[i].label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _filterIndex == i
                        ? AppColors.onPrimaryOf(context)
                        : AppColors.text2Of(context),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('这里还没有往期病例',
            style: TextStyle(fontSize: 13, color: AppColors.text3Of(context))),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return _buildItem(_items[i]);
        },
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final done = item['done'] as bool? ?? false;
    final score = (item['myScore'] as num?)?.toDouble();
    final difficulty = (item['difficulty'] as num?)?.toInt() ?? 2;
    final diffColor = difficulty <= 1
        ? AppColors.moss3Of(context)
        : difficulty == 2
            ? AppColors.amberOf(context)
            : AppColors.vermilionOf(context);
    final diffText = difficulty <= 1 ? '入门' : difficulty == 2 ? '进阶' : '挑战';

    return AppPressable(
      onTap: () async {
        final scheduleId = (item['scheduleId'] as num?)?.toInt();
        if (scheduleId == null) return;
        await context.pushNamed(
          done ? RouteNames.mrReport : RouteNames.mrWorkshop,
          pathParameters: {'scheduleId': '$scheduleId'},
        );
        _refresh();
      },
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(diffText,
                          style: TextStyle(fontSize: 11, color: diffColor,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(item['department'] as String? ?? '',
                          style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
                      const Spacer(),
                      Text(item['publishDate'] as String? ?? '',
                          style: TextStyle(fontSize: 11, color: AppColors.text4Of(context))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item['caseTitle'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOf(context))),
                  const SizedBox(height: 4),
                  Text(
                    done
                        ? (score != null ? '我的得分 ${score.toStringAsFixed(0)} 分' : '已提交，待批阅')
                        : '未完成 · 点击补写',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: done ? AppColors.moss3Of(context) : AppColors.text4Of(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              size: done ? 20 : 22,
              color: done ? AppColors.moss3Of(context) : AppColors.text4Of(context),
            ),
          ],
        ),
      ),
    );
  }
}
