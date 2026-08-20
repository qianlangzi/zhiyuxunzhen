import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/teacher_service.dart';

/// 学情看板
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _aiInsightLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Future<void> _loadDashboard() async {
    Map<String, dynamic>? data;
    try {
      data = await TeacherService().getDashboardOverview();
    } catch (e) {
      // 兜底：加载异常也要结束 loading，避免页面永久转圈、无法返回
      debugPrint('loadDashboard error: $e');
    }
    if (mounted) {
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    }
  }

  /// AI 班级学情洞察（纯统计归纳，无新增数据）
  Future<void> _loadInsight() async {
    if (_aiInsightLoading) return;
    setState(() => _aiInsightLoading = true);
    final result = await TeacherService().getClassInsight();
    if (!mounted) return;
    setState(() => _aiInsightLoading = false);
    if (result == null) {
      AppFeedback.error(context, 'AI 暂不可用，无法生成学情洞察');
      return;
    }
    _showInsightSheet(result);
  }

  void _showInsightSheet(Map<String, dynamic> result) {
    final weaknessAnalysis = result['weaknessAnalysis'] as String? ?? '';
    final focus = result['recommendedFocus'] as String? ?? '';
    final suggestions = (result['teachingSuggestions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ruleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SerifText('AI 教学洞察 · 基于真实数据', fontSize: 17),
                  ),
                  const AppChip(label: 'AI', type: ChipType.moss),
                ],
              ),
              const SizedBox(height: 4),
              MonoText('仅归纳看板真实统计，不新增任何数字', fontSize: 11, color: AppColors.text3Of(context)),
              Divider(height: 20, color: AppColors.ruleOf(context)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (weaknessAnalysis.isNotEmpty)
                      _insightBlock('薄弱点分析', weaknessAnalysis),
                    if (suggestions.isNotEmpty) ...[
                      _insightBlock('教学建议', ''),
                      ...suggestions.asMap().entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOf(context),
                          border: Border.all(color: AppColors.surfaceEdgeOf(context)),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonoText('建议 ${e.key + 1} · ${e.value['topic'] ?? ''}',
                                fontSize: 11, color: AppColors.primaryOf(context)),
                            const SizedBox(height: 6),
                            Text('${e.value['suggestion'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
                            const SizedBox(height: 4),
                            MonoText('依据：${e.value['evidence'] ?? ''}',
                                fontSize: 11, color: AppColors.text3Of(context)),
                          ],
                        ),
                      )),
                    ],
                    if (focus.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EyebrowText('优先整改方向', color: AppColors.onPrimarySoftOf(context)),
                            const SizedBox(height: 6),
                            Text(focus,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onPrimaryOf(context),
                                    height: 1.6)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightBlock(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(title.toUpperCase(), fontSize: 11, color: AppColors.primaryOf(context), letterSpacing: 0.06),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content,
                style: TextStyle(fontSize: 12.5, color: AppColors.textOf(context), height: 1.6)),
          ],
        ],
      ),
    );
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
              title: '学情看板 · 心血管 03',
              onBack: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.teacherHome),
              action: AppGhostButton(
                label: _aiInsightLoading ? '洞察中…' : 'AI 教学洞察',
                small: true,
                onPressed: _aiInsightLoading ? null : _loadInsight,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatGrid(),
                          _buildOsceSection(context),
                          _buildCommonMissSection(context),
                          _buildMisdiagnosisSection(context),
                          _buildRemediation(context),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    final data = _dashboardData;

    // 从后端真实字段解析（TeacherDashboardVO）
    final completionRate = (data?['completionRate'] as num?)?.toDouble() ?? 0.0;
    final avgOsceScore = (data?['avgOsceScore'] as num?)?.toDouble() ?? 0.0;
    final reviewEfficiency = (data?['reviewEfficiency'] as num?)?.toDouble() ?? 0.0;
    final overExamRate = (data?['overExamRate'] as num?)?.toDouble() ?? 0.0;

    final stats = <(String, String, String, Color)>[
      ('作业完成率', '${(completionRate * 100).toStringAsFixed(0)}%', '基于已提交作业', AppColors.moss),
      ('平均 OSCE', avgOsceScore.toStringAsFixed(1), '基于批阅记录', AppColors.moss),
      ('批阅效率', '${reviewEfficiency.toStringAsFixed(1)}', '批阅数/作业总数', AppColors.moss),
      ('过度检查率', '${(overExamRate * 100).toStringAsFixed(0)}%', '超均费用占比', AppColors.vermilion),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: 4,
      itemBuilder: (context, i) {
        final (label, value, trend, color) = stats[i];
        final isNegativeTrend = label == '过度检查率' && overExamRate > 0.3;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadow.card(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoText(label.toUpperCase(), fontSize: 10, color: AppColors.text3Of(context), letterSpacing: 0.1),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOf(context),
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 2),
              MonoText(trend, fontSize: 11, color: isNegativeTrend ? AppColors.vermilion : AppColors.primaryOf(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOsceSection(BuildContext context) {
    final data = _dashboardData;
    // 后端返回 osceDimensionScores: Map<String, Integer>
    final osceDimScores = (data?['osceDimensionScores'] as Map<String, dynamic>?) ?? {};
    final avgOsceScore = (data?['avgOsceScore'] as num?)?.toDouble() ?? 0.0;

    // 维度中文名映射（后端 key 可能是英文或中文）
    final dimLabels = <String, String>{
      'history': '病史采集',
      'diagnosis': '诊断逻辑',
      'communication': '沟通技巧',
      'humanism': '人文关怀',
      'examination': '检查决策',
      'documentation': '文书规范',
    };

    final osceRows = osceDimScores.entries.map((e) {
      final label = dimLabels[e.key] ?? e.key;
      final score = (e.value as num?)?.toDouble() ?? 0.0;
      final color = score >= 85 ? AppColors.moss : (score >= 75 ? AppColors.amber : AppColors.vermilion);
      return (label, score.toStringAsFixed(1), color);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '01', title: 'OSCE 六维均分'),
        AppPaper(
          child: osceRows.isEmpty
              ? _buildEmptyHint(context, '暂无 OSCE 评分数据')
              : Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CustomPaint(
                        painter: _MiniRadarPainter(
                          ruleColor: AppColors.ruleOf(context),
                          mossColor: AppColors.primaryOf(context),
                          scores: osceDimScores.values.map((v) => ((v as num?)?.toDouble() ?? 0.0) / 100.0).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          ...osceRows.map((r) => _osceRow(context, r.$1, r.$2, r.$3)),
                          const DottedDivider(),
                          _osceRow(context, '综合均分', avgOsceScore.toStringAsFixed(1), AppColors.moss, bold: true),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: MonoText(text, fontSize: 12, color: AppColors.text4Of(context)),
      ),
    );
  }

  Widget _osceRow(BuildContext context, String label, String score, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bold ? 13 : 12,
                fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
                color: AppColors.text2Of(context),
              ),
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonMissSection(BuildContext context) {
    final data = _dashboardData;
    // 后端返回 commonMistakes: List<CommonMistake{type, description, count}>
    final missItems = (data?['commonMistakes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    // 找最大 count 用于计算 barPercent
    final maxCount = missItems.isEmpty ? 1 : missItems.map((m) => (m['count'] as num?)?.toInt() ?? 0).fold(0, (a, b) => a > b ? a : b);

    final items = missItems.map((m) {
      final name = m['description'] as String? ?? m['type'] as String? ?? '';
      final count = (m['count'] as num?)?.toInt() ?? 0;
      final barPercent = maxCount == 0 ? 0.0 : count / maxCount;
      return (name, count, barPercent);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          number: '02',
          title: '共性错题',
          trailing: Builder(builder: (ctx) => AppMoreLink(label: 'Top 5', onTap: () => AppFeedback.info(ctx, '已展示 Top 5 错题'))),
        ),
        AppPaper(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: items.isEmpty
              ? _buildEmptyHint(context, '暂无错题数据')
              : Column(
                  children: items.map((e) => _missRow(context, e.$1, e.$2, e.$3)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _missRow(BuildContext context, String name, int count, double barPercent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)))),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            height: 4,
            child: AppProgressBar(value: barPercent, height: 4, foregroundColor: AppColors.vermilion, radius: 2),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.vermilion,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMisdiagnosisSection(BuildContext context) {
    // 后端 TeacherDashboardVO 未提供误诊统计字段
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(number: '03', title: '共性误诊'),
        AppPaper(
          child: _buildEmptyHint(context, '暂无误诊统计数据'),
        ),
      ],
    );
  }

Widget _buildRemediation(BuildContext context) {
    final data = _dashboardData;
    final remediation = data?['remediationSuggestion'] as String?;
    if (remediation == null || remediation.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowText('REMEDIATION · 课堂补救建议', color: AppColors.onPrimarySoftOf(context)),
          const SizedBox(height: 8),
          Text(
            remediation,
            style: TextStyle(fontSize: 13, color: AppColors.onPrimaryOf(context), height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _MiniRadarPainter extends CustomPainter {
  final Color ruleColor;
  final Color mossColor;
  final List<double> scores;

  _MiniRadarPainter({required this.ruleColor, required this.mossColor, List<double>? scores})
      : scores = scores ?? const [];
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.38;

    final n = scores.isEmpty ? 6 : scores.length;
    final angleStep = 2 * pi / n;

    // 无数据时只画网格
    if (scores.isEmpty) {
      final gridPaint = Paint()
        ..color = ruleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var level = 1; level <= 2; level++) {
        final r = radius * level / 2;
        final path = Path();
        for (var i = 0; i <= n; i++) {
          final angle = -pi / 2 + i * angleStep;
          final x = cx + r * cos(angle);
          final y = cy + r * sin(angle);
          if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
        }
        canvas.drawPath(path, gridPaint);
      }
      return;
    }

    // 网格
    final gridPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var level = 1; level <= 2; level++) {
      final r = radius * level / 2;
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final angle = -pi / 2 + i * angleStep;
        final x = cx + r * cos(angle);
        final y = cy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // 数据
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final r = radius * scores[i];
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = mossColor.withValues(alpha: 0.15)..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()..color = mossColor..style = PaintingStyle.stroke..strokeWidth = 2);

    // 点
    final dotPaint = Paint()..color = mossColor;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final r = radius * scores[i];
      canvas.drawCircle(Offset(cx + r * cos(angle), cy + r * sin(angle)), 3, dotPaint);
    }
  }

  @override
bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
