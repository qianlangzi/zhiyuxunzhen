import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../data/student_service.dart';
import '../growth/widgets/mistake_tile.dart';

/// 学生端 · 错题本（成长页的二级页）
///
/// 原成长 Tab 承担了「数据可视化 + 全部错题列表 + 全部功能入口」三重职责，
/// 页面又长又杂。现职责收敛：
/// - 成长页（GrowthScreen）只看进步：主卡 / 热力图 / 能力评分 / 待复盘前 3 条；
/// - 本页承接完整错题列表：状态统计 + 类型筛选 + AI 归因 + 标记掌握 + 导出 PDF。
class MistakeBookScreen extends ConsumerStatefulWidget {
  const MistakeBookScreen({super.key});

  @override
  ConsumerState<MistakeBookScreen> createState() => _MistakeBookScreenState();
}

class _MistakeBookScreenState extends ConsumerState<MistakeBookScreen> {
  String _selectedFilter = '全部';

  List<MistakeEntry> _mistakes = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final raw = await StudentService().getMistakes(pageNum: 1, pageSize: 100);
    if (!mounted) return;
    final list = (raw?['records'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => MistakeEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    setState(() {
      _mistakes = list;
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _analyze(int id) =>
      StudentService().analyzeMistake(id);

  List<MistakeEntry> get _filtered {
    final kw = MistakeEntry.keywordOf(_selectedFilter);
    if (kw == null) return _mistakes;
    return _mistakes.where((m) => m.typeKey == kw).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreviewed = _mistakes.where((m) => m.resolvedStatus == 0).length;
    final reviewed = _mistakes.where((m) => m.resolvedStatus == 1).length;
    final mastered = _mistakes.where((m) => m.mastered).length;
    final list = _filtered;

    return AmbientScaffold(
      tag: '成长 · 记录',
      title: '错题本',
      subtitle: '共 ${_mistakes.length} 条 · 待复盘 $unreviewed 条',
      onBack: () => context.canPop() ? context.pop() : null,
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 40,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildStatusRow(unreviewed, reviewed, mastered),
          const SizedBox(height: 14),
          _buildFilterBar(),
          const SizedBox(height: 6),
          if (list.isEmpty)
            _buildEmpty()
          else
            ...list.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MistakeTile(
                  entry: m,
                  onAnalyze: _analyze,
                  onMarkMastered: (e) =>
                      setState(() => e.resolvedStatus = 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 状态统计 —— 三张带色晕的小卡
  Widget _buildStatusRow(int unreviewed, int reviewed, int mastered) {
    return Row(
      children: [
        _statusCard('未复习', unreviewed, AppColors.vermilionOf(context)),
        const SizedBox(width: 10),
        _statusCard('已复习', reviewed, AppColors.amberOf(context)),
        const SizedBox(width: 10),
        _statusCard('已掌握', mastered, AppColors.primaryOf(context)),
      ],
    );
  }

  Widget _statusCard(String label, int count, Color color) {
    return Expanded(
      child: PaperCard(
        tint: color,
        radius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.1,
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: kCjkMonoFallback,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: AppColors.text3Of(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MistakeEntry.filterLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = MistakeEntry.filterLabels[i];
          final active = label == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryOf(context)
                    : AppColors.surfaceOf(context),
                border: Border.all(
                  color: active
                      ? AppColors.primaryOf(context)
                      : AppColors.ruleOf(context),
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: active
                      ? AppColors.onPrimaryOf(context)
                      : AppColors.text2Of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined,
              size: 40, color: AppColors.text4Of(context)),
          const SizedBox(height: 12),
          Text(
            _selectedFilter == '全部' ? '还没有错题，继续保持' : '该分类暂无错题',
            style: TextStyle(fontSize: 14, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 4),
          MonoText('当前筛选：$_selectedFilter',
              fontSize: 11, color: AppColors.text4Of(context)),
        ],
      ),
    );
  }
}
