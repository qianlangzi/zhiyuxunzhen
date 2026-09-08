import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../data/student_service.dart';
import '../growth/growth_stats.dart';
import '../growth/widgets/weakness_list_card.dart';
import '../recommend/learning_path_screen.dart';

/// 学习档案页（P2-1 学习档案/目标管理）
///
/// 职责收敛：学习目标 + 薄弱点 Top + 继续学习。
/// 此前内嵌的「学习数据统计」与「12 周热力图」和成长页完全重复，已删除——
/// 热力图统一由成长页的 [StudyHeatmapCard] 呈现，本页聚焦「目标与薄弱点」。
class LearningArchiveScreen extends ConsumerStatefulWidget {
  const LearningArchiveScreen({super.key});

  @override
  ConsumerState<LearningArchiveScreen> createState() =>
      _LearningArchiveScreenState();
}

class _LearningArchiveScreenState extends ConsumerState<LearningArchiveScreen> {
  Map<String, dynamic>? _goal;
  GrowthStats _stats = GrowthStats.fromOverview(null);
  List<dynamic> _weaknesses = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final service = StudentService();
    final results = await Future.wait([
      service.myGoal(),
      service.getReportOverview(),
      service.getWeaknesses(),
    ]);
    if (!mounted) return;
    setState(() {
      _goal = results[0] as Map<String, dynamic>?;
      _stats = GrowthStats.fromOverview(results[1] as Map<String, dynamic>?);
      _weaknesses = results[2] as List<dynamic>? ?? const [];
      _isLoading = false;
    });
  }

  Future<void> _editGoal() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _GoalEditDialog(initial: _goal),
    );
    if (result == null || !mounted) return;
    final ok = await StudentService().upsertGoal(
      title: result['title'] ?? '',
      targetMetric: result['metric'] ?? '',
      targetDate: result['date'] ?? '',
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学习目标已保存')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '成长 · 档案',
      title: '学习档案',
      subtitle: '目标 · 薄弱点 · 下一步去哪补',
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      loading: _isLoading,
      onRefresh: _load,
      bottomInset: 40,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildGoalCard(),
          const SizedBox(height: 16),
          _buildWeaknessCard(),
          const SizedBox(height: 16),
          _buildShortcuts(),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
    final title = (_goal?['title'] as String?)?.trim() ?? '';
    final metric = (_goal?['targetMetric'] as String?)?.trim() ?? '';
    final date = (_goal?['targetDate'] as String?) ?? '';
    final hasGoal = title.isNotEmpty || metric.isNotEmpty;

    return PaperCard(
      tint: AppColors.primaryOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.flag_circle_outlined,
                color: AppColors.primaryOf(context),
                size: 34,
              ),
              const SizedBox(width: 9),
              Text(
                '学习目标',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _editGoal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOf(context).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    hasGoal ? '修改' : '设定',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.primaryOf(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasGoal)
            Text(
              '还没有设定目标，点击右上角设定你的个性化学习目标吧。',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: AppColors.text3Of(context)),
            )
          else ...[
            Text(
              title,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AppColors.textOf(context)),
            ),
            if (metric.isNotEmpty) ...[
              const SizedBox(height: 8),
              _metaRow(context, Icons.speed_rounded, '量化指标 · $metric'),
            ],
            if (date.isNotEmpty) ...[
              const SizedBox(height: 5),
              _metaRow(context, Icons.event_outlined, '目标日期 · $date'),
            ],
          ],
          if (_stats.hasActivity) ...[
            const SizedBox(height: 13),
            const DottedDivider(),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '累计训练 ${_stats.totalTrainings} 次 · 连续 ${_stats.streakDays} 天',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.text3Of(context)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.text4Of(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: 12, height: 1.4, color: AppColors.text2Of(context))),
        ),
      ],
    );
  }

  Widget _buildWeaknessCard() {
    return WeaknessListCard(
      weaknesses: _weaknesses,
      onAiDiagnosis: () => context.pushNamed(RouteNames.recommendation),
    );
  }

  Widget _buildShortcuts() {
    // 入口统一原则：错题本 → 成长页「待复盘」方块；考核记录 → 「训练概览」子页。
    // 本区只保留 AI 学习路径（学习教练 Agent 生成），避免与成长页重复。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: MonoText('AI 学习教练',
              fontSize: 10,
              color: AppColors.text4Of(context),
              letterSpacing: 0.12),
        ),
        PaperCard(
          tint: AppColors.primaryOf(context),
          radius: AppRadius.lg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearningPathScreen()),
          ),
          child: Row(
            children: [
              GradientIconBadge(
                icon: Icons.route_rounded,
                color: AppColors.primaryOf(context),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的学习路径',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '按你的薄弱点生成递进式补练计划',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.text4Of(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.text4Of(context)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 目标设定弹窗
class _GoalEditDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _GoalEditDialog({this.initial});

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _metric;
  late final TextEditingController _date;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
        text: (widget.initial?['title'] as String?) ?? '');
    _metric = TextEditingController(
        text: (widget.initial?['targetMetric'] as String?) ?? '');
    _date = TextEditingController(
        text: (widget.initial?['targetDate'] as String?) ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _metric.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('设定学习目标'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            maxLength: 200,
            decoration:
                const InputDecoration(labelText: '目标标题（如：冲刺 OSCE 85 分）'),
          ),
          TextField(
            controller: _metric,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '量化指标（如：OSCE 均分≥85）'),
          ),
          TextField(
            controller: _date,
            decoration: const InputDecoration(labelText: '目标日期（如：2026-09-30）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop({
            'title': _title.text.trim(),
            'metric': _metric.text.trim(),
            'date': _date.text.trim(),
          }),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
