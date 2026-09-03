import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../../shared/widgets/study_heatmap.dart';
import '../data/student_service.dart';
import 'growth_stats.dart';
import 'widgets/growth_visual.dart';
import 'widgets/mistake_tile.dart';

/// 学生端 Tab3 · 成长
///
/// 定位：只看「进步」，不做功能堆砌。
/// 主视觉顺序：成长主卡（连续天数环）→ 学习热力图（页面主角）→ 能力评分 → 待复盘错题。
/// 完整错题列表下沉到「错题本」二级页（[RouteNames.mistakeBook]）。
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  bool _isLoading = true;
  GrowthStats _stats = GrowthStats.fromOverview(null);
  List<MistakeEntry> _mistakes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      StudentService().getReportOverview(),
      StudentService().getMistakes(pageNum: 1, pageSize: 50),
    ]);
    if (!mounted) return;
    final overview = results[0];
    final raw = results[1];
    final list = (raw?['records'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => MistakeEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    setState(() {
      _stats = GrowthStats.fromOverview(overview);
      _mistakes = list;
      _isLoading = false;
    });
  }

  int get _masteredCount => _mistakes.where((m) => m.mastered).length;

  List<MistakeEntry> get _pending =>
      _mistakes.where((m) => m.resolvedStatus == 0).toList();

  String get _subtitle {
    if (_stats.streakDays > 0) {
      return '已连续训练 ${_stats.streakDays} 天 · 累计 ${_stats.totalTrainings} 次';
    }
    if (_stats.totalTrainings > 0) {
      return '累计训练 ${_stats.totalTrainings} 次 · 今天开个头吧';
    }
    return '还没有训练记录，去完成一次问诊试试';
  }

  Future<Map<String, dynamic>?> _analyze(int id) =>
      StudentService().analyzeMistake(id);

  void _markMastered(MistakeEntry e) {
    setState(() => e.resolvedStatus = 2);
    AppFeedback.success(context, '已标记为已掌握');
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '内科教研 · 学生端',
      title: '成长',
      subtitle: _subtitle,
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 104,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 104),
        children: [
          GrowthHeroCard(
            stats: _stats,
            masteredCount: _masteredCount,
          ),
          const SizedBox(height: 14),
          StudyHeatmapCard(
            activityDays: _stats.activityDays,
            stats: _stats,
            onDetail: () => context.pushNamed(RouteNames.learningArchive),
          ),
          if (_stats.hasAbility) ...[
            const SizedBox(height: 14),
            AbilityPanel(stats: _stats),
          ],
          const SizedBox(height: 22),
          _buildPendingSection(),
          const SizedBox(height: 20),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }

  /// 待复盘错题 —— 只放前 3 条，其余进错题本二级页
  Widget _buildPendingSection() {
    final pending = _pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperSectionLabel(
          title: '待复盘',
          icon: Icons.fact_check_outlined,
          meta: pending.isEmpty ? '已全部清零' : '${pending.length} 条待处理',
          onMore: pending.isEmpty
              ? null
              : () => context.pushNamed(RouteNames.mistakeBook),
        ),
        const SizedBox(height: 11),
        if (pending.isEmpty)
          PaperCard(
            tint: AppColors.moss,
            radius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 30, color: AppColors.primaryOf(context)),
                  const SizedBox(height: 9),
                  Text(
                    '错题都复盘完了，厉害',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.text2Of(context)),
                  ),
                  const SizedBox(height: 3),
                  MonoText('新的错题会在这里出现',
                      fontSize: 11, color: AppColors.text4Of(context)),
                ],
              ),
            ),
          )
        else
          ...pending.take(3).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MistakeTile(
                    entry: m,
                    compact: true,
                    onAnalyze: _analyze,
                    onMarkMastered: _markMastered,
                  ),
                ),
              ),
      ],
    );
  }
}
