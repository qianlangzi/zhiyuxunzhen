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
import '../../common/guide/guide_anchor.dart';
import '../data/student_service.dart';
import 'growth_stats.dart';
import 'widgets/ability_radar.dart';
import 'widgets/growth_garden.dart';
import 'widgets/growth_visual.dart';
import 'widgets/mistake_tile.dart';

/// 学生端 Tab3 · 成长
///
/// 定位：**只讲进步，不做报表**。叙事顺序由「感受」递进到「事实」：
///   1. 成长花园 Hero —— 一株随数据生长的植物 + 一句治愈文案 + 两个关键数字
///   2. 学习热力 —— 坚持留下的痕迹（精简头部，不与 Hero 重复报数）
///   3. 能力画像 —— 一张雷达图看完强弱（替掉六条进度条）
///   4. 训练概览 —— 唯一一处聚焦数字的卡（正确率一个焦点）
///   5. 待复盘 —— 从「看」落到「做」，只放 3 条，其余进错题本
///
/// 卡片依次上浮入场（[RiseIn]），刷题统计异步浮现不阻塞整页；深浅模式自适应。
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  bool _statsReady = false;
  bool _questionLoading = true;
  GrowthStats _stats = GrowthStats.fromOverview(null);
  QuestionStats _question = QuestionStats.fromApi(null);
  List<MistakeEntry> _mistakes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // 先走快路径：概览 + 错题，尽快铺出页面主体（花园 / 热力 / 能力 / 待复盘）。
    setState(() {
      _statsReady = false;
      _questionLoading = true;
    });
    final results = await Future.wait([
      StudentService().getReportOverview(),
      StudentService().getMistakes(pageNum: 1, pageSize: 50),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = GrowthStats.fromOverview(results[0]);
      final raw = results[1];
      _mistakes = (raw?['list'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => MistakeEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _statsReady = true;
    });
    // 再异步拉刷题统计：慢数据不阻塞整页，到账后训练卡骨架淡入真实内容。
    final q = await StudentService().getQuestionStats();
    if (!mounted) return;
    setState(() {
      _question = QuestionStats.fromApi(q);
      _questionLoading = false;
    });
  }

  List<MistakeEntry> get _pending =>
      _mistakes.where((m) => m.resolvedStatus == 0).toList();

  Future<Map<String, dynamic>?> _analyze(int id) =>
      StudentService().analyzeMistake(id);

  void _markMastered(MistakeEntry e) {
    setState(() => e.resolvedStatus = 2);
    AppFeedback.success(context, '已标记为已掌握');
  }

  /// 副标题：不重复卡片里的具体数字，只给一句状态
  String get _subtitle {
    if (!_stats.hasActivity && !_question.hasData) {
      return '还没有学习记录，从一次问诊或刷题开始吧';
    }
    if (_question.hasData && _question.accuracy >= 0.85) {
      return '正确率很稳，继续保持好状态';
    }
    if (_question.hasData && _question.accuracy >= 0.7) {
      return '状态在线，攻克剩下的薄弱模块吧';
    }
    return '坚持练习，把错题变成能力';
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      tag: '内科教研 · 学生端',
      title: '成长',
      subtitle: _subtitle,
      loading: !_statsReady,
      onRefresh: _load,
      bottomInset: 104,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          // 1 · 情感锚点：一株会生长的植物
          RiseIn(child: GrowthGardenCard(stats: _stats)),
          const SizedBox(height: 16),
          // 2 · 坚持的痕迹（套 GuideTarget：新手指引会高亮热力图）
          RiseIn(
            delay: const Duration(milliseconds: 60),
            child: GuideTarget(
              anchor: GuideAnchors.studentGrowthHeatmap,
              child: StudyHeatmapCard(
                activityDays: _stats.activityDays,
                stats: _stats,
                dense: true,
                onDetail: () => context.pushNamed(RouteNames.learningArchive),
              ),
            ),
          ),
          // 3 · 能力形状
          if (_stats.hasAbility) ...[
            const SizedBox(height: 16),
            RiseIn(
              delay: const Duration(milliseconds: 120),
              child: AbilityRadarCard(stats: _stats),
            ),
          ],
          // 4 · 唯一一处聚焦数字的卡
          const SizedBox(height: 16),
          RiseIn(
            delay: const Duration(milliseconds: 180),
            child: TrainingOverviewCard(
              question: _question,
              loading: _questionLoading,
            ),
          ),
          const SizedBox(height: 24),
          // 5 · 落到行动
          RiseIn(
            delay: const Duration(milliseconds: 240),
            child: _buildPendingSection(),
          ),
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
            tint: AppColors.primaryOf(context),
            radius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 30, color: AppColors.primaryOf(context),),
                  const SizedBox(height: 9),
                  Text(
                    '错题都复盘完了，厉害',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.text2Of(context),),
                  ),
                  const SizedBox(height: 3),
                  MonoText('新的错题会在这里出现',
                      fontSize: 11, color: AppColors.text4Of(context),),
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
