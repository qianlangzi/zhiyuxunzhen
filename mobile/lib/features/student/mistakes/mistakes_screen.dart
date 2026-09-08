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
/// - 本页承接完整错题列表：状态统计 + 来源筛选；单条复盘进详情二级页。
class MistakeBookScreen extends ConsumerStatefulWidget {
  const MistakeBookScreen({super.key});

  @override
  ConsumerState<MistakeBookScreen> createState() => _MistakeBookScreenState();
}

class _MistakeBookScreenState extends ConsumerState<MistakeBookScreen> {
  /// 一级筛选：来源（全部 / 刷题 / 问诊 / 主观题）
  String _selectedSource = '全部';

  /// 二级筛选：问诊错因细分（仅来源=问诊时生效；'全部' = 不细分）
  String _consultSub = '全部';

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
    final list = (raw?['list'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => MistakeEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    setState(() {
      _mistakes = list;
      _isLoading = false;
    });
  }

  List<MistakeEntry> get _filtered {
    final sourceKey = MistakeEntry.sourceFilterLabels.contains(_selectedSource)
        ? _sourceKeyOf(_selectedSource)
        : null;
    var list = sourceKey == null
        ? _mistakes
        : _mistakes.where((m) => m.sourceKey == sourceKey).toList();
    // 问诊来源下可再按错因细分（诊断/病史/检查/文书/沟通）
    if (_selectedSource == '问诊' && _consultSub != '全部') {
      final sub = MistakeEntry.keywordOf(_consultSub);
      if (sub != null) {
        list = list.where((m) => m.typeKey == sub).toList();
      }
    }
    return list;
  }

  String? _sourceKeyOf(String zh) {
    switch (zh) {
      case '刷题':
        return 'practice';
      case '问诊':
        return 'consult';
      case '主观题':
        return 'essay';
      default:
        return null; // 全部
    }
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
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 状态统计 —— 三张小卡：左侧色条 + 数字着色；
  /// 计数为 0 时整体弱化为灰，不再整卡铺满色晕。
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
    final hasData = count > 0;
    return Expanded(
      child: PaperCard(
        tint: hasData ? color : AppColors.text4Of(context),
        tintStrength: hasData ? 0.45 : 0.18,
        radius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(vertical: 13),
        accent: hasData ? color : null,
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
                color: hasData ? color : AppColors.text4Of(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: hasData
                    ? AppColors.text3Of(context)
                    : AppColors.text4Of(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MistakeEntry.sourceFilterLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final label = MistakeEntry.sourceFilterLabels[i];
              final active = label == _selectedSource;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedSource = label;
                  _consultSub = '全部'; // 切来源时重置二级细分
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
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
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? AppColors.onPrimaryOf(context)
                          : AppColors.text2Of(context),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 来源=问诊时展开二级错因细分
        if (_selectedSource == '问诊') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MistakeEntry.consultSubLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final label = MistakeEntry.consultSubLabels[i];
                final active = label == _consultSub;
                return GestureDetector(
                  onTap: () => setState(() => _consultSub = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryOf(context).withValues(alpha: 0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: active
                            ? AppColors.primaryOf(context)
                            : AppColors.ruleOf(context),
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: active
                            ? AppColors.primaryOf(context)
                            : AppColors.text3Of(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
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
            _selectedSource == '全部' ? '还没有错题，继续保持' : '该分类暂无错题',
            style: TextStyle(fontSize: 14, color: AppColors.text3Of(context)),
          ),
          const SizedBox(height: 4),
          MonoText(
              '当前筛选：$_selectedSource'
              '${_selectedSource == '问诊' && _consultSub != '全部' ? ' · $_consultSub' : ''}',
              fontSize: 11, color: AppColors.text4Of(context),),
        ],
      ),
    );
  }
}
