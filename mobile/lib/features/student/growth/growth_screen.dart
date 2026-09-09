import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/route_names.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/paper_surfaces.dart';
import '../../../shared/widgets/study_heatmap.dart';
import '../../common/guide/guide_anchor.dart';
import '../data/student_service.dart';
import 'growth_stats.dart';
import 'widgets/growth_entry_grid.dart';
import 'widgets/growth_garden.dart';
import 'widgets/mistake_tile.dart';

/// 学生端 Tab3 · 成长
///
/// 定位：**只讲进步，不做报表**。首页只保留情感锚点与入口，细节全部下沉二级页：
///   1. 成长花园 Hero —— 一株随数据生长的植物 + 一句治愈文案
///   2. 学习热力 —— 坚持留下的痕迹
///   3. 子级入口方块 —— 能力画像 / 训练概览 / 待复盘 / 学习档案
///
/// 此前雷达图、训练数字、待复盘列表全部平铺在本页，信息密度过高且与
/// 学习档案内容交叉重复；现统一收敛为「入口方块 → 二级页」的层级结构。
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  /// 已就绪的接口计数（0~3）。三接口分步就绪分步渲染，
  /// 避免「最慢的统计接口拖住整页」的木桶效应。
  int _readyCount = 0;

  /// 加载批次号：防止快速下拉刷新时旧批次迟到响应污染新批次计数
  int _loadSeq = 0;

  GrowthStats _stats = GrowthStats.fromOverview(null);
  QuestionStats _question = QuestionStats.fromApi(null);
  List<MistakeEntry> _mistakes = const [];

  bool get _statsReady => _readyCount >= 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _readyCount = 0);
    await Future.wait([
      _loadOverview(seq),
      _loadMistakes(seq),
      _loadStats(seq),
    ]);
  }

  /// 各接口独立就绪：谁先回来谁先渲染，骨架屏只挡最慢的那块数字
  Future<void> _loadOverview(int seq) async {
    final data = await StudentService().getReportOverview();
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _stats = GrowthStats.fromOverview(data);
      _readyCount++;
    });
  }

  Future<void> _loadMistakes(int seq) async {
    final raw = await StudentService().getMistakes(pageNum: 1, pageSize: 50);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _mistakes = (raw?['list'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => MistakeEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _readyCount++;
    });
  }

  Future<void> _loadStats(int seq) async {
    final data = await StudentService().getQuestionStats();
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _question = QuestionStats.fromApi(data);
      _readyCount++;
    });
  }

  List<MistakeEntry> get _pending =>
      _mistakes.where((m) => m.resolvedStatus == 0).toList();

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
      tag: '新医科 · 学生端',
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
          const SizedBox(height: 22),
          // 3 · 子级入口：能力画像 / 训练概览 / 待复盘 / 学习档案
          RiseIn(
            delay: const Duration(milliseconds: 120),
            child: GrowthEntryGrid(entries: _buildEntries(context)),
          ),
          const SizedBox(height: 20),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }

  List<GrowthEntryItem> _buildEntries(BuildContext context) {
    final pending = _pending.length;
    return [
      GrowthEntryItem(
        icon: Icons.radar_rounded,
        label: '能力画像',
        color: AppColors.indigoOf(context),
        meta: _stats.hasAbility
            ? '综合 ${_stats.osceAvg.toStringAsFixed(1)} 分'
            : '完成问诊后生成',
        onTap: () => context.pushNamed(RouteNames.abilityProfile),
      ),
      GrowthEntryItem(
        icon: Icons.track_changes_rounded,
        label: '训练概览',
        color: AppColors.primaryOf(context),
        meta: _question.hasData
            ? '正确率 ${(_question.accuracy * 100).round()}%'
            : '还没有刷题记录',
        onTap: () => context.pushNamed(RouteNames.trainingOverview),
      ),
      GrowthEntryItem(
        icon: Icons.fact_check_outlined,
        label: '待复盘',
        color: AppColors.vermilionOf(context),
        meta: pending > 0 ? '$pending 条错题待处理' : '错题已全部清零',
        onTap: () => context.pushNamed(RouteNames.mistakeBook),
      ),
      GrowthEntryItem(
        icon: Icons.folder_copy_outlined,
        label: '学习档案',
        color: AppColors.amberOf(context),
        meta: '目标 · 薄弱点 · 路径',
        onTap: () => context.pushNamed(RouteNames.learningArchive),
      ),
    ];
  }
}
