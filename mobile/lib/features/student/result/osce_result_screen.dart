import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../../../routes/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_service.dart';

/// OSCE 四维评分结果页
class OsceResultScreen extends ConsumerStatefulWidget {
  const OsceResultScreen({super.key});

  @override
  ConsumerState<OsceResultScreen> createState() => _OsceResultScreenState();
}

class _OsceResultScreenState extends ConsumerState<OsceResultScreen> {
  Map<String, dynamic>? _evaluation;
  bool _isLoading = true;
  bool _isRetrying = false;
  int? _sessionId;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvaluation());
  }

  Future<void> _loadEvaluation() async {
    final state = GoRouterState.of(context);
    final qs = state.uri.queryParameters['sessionId'];
    final parsed = qs == null ? null : int.tryParse(qs);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _isLoading = false;
        _errorMsg = '缺少会话 ID';
      });
      return;
    }
    _sessionId = parsed;
    final data = await StudentService().getSessionEvaluation(parsed);
    if (!mounted) return;
    setState(() {
      _evaluation = data;
      _isLoading = false;
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
              title: 'OSCE 考核结果',
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.studentHome),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_evaluation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.text4Of(context)),
            const SizedBox(height: 12),
            Text(_errorMsg ?? '暂无评分数据',
                style: TextStyle(fontSize: 14, color: AppColors.text3Of(context))),
            const SizedBox(height: 16),
            AppGhostButton(
              label: '返回首页',
              onPressed: () => context.goNamed(RouteNames.studentHome),
            ),
          ],
        ),
      );
    }
    if (_evaluation!['status'] == 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_problem, size: 48, color: AppColors.vermilionOf(context)),
              const SizedBox(height: 12),
              Text('问诊已结束，但 AI 评估尚未完成', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textOf(context))),
              const SizedBox(height: 8),
              Text('不会影响已保存的问诊记录。可以立即重试，成功后将显示评分报告。', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text3Of(context))),
              const SizedBox(height: 18),
              AppPrimaryButton(
                label: _isRetrying ? '正在重试…' : '重试生成评估',
                icon: const Icon(Icons.refresh, size: 16),
                fullWidth: true,
                onPressed: _isRetrying ? null : _retryArchive,
              ),
            ],
          ),
        ),
      );
    }
    final scores = _extractScores();
    final totalScore = _extractTotalScore();
    final strengths = _extractStringList('strengths');
    final improvements = _extractStringList('improvements');
    final finalReport = _evaluation!['finalReport'] as String? ?? '';
    final patientScore =
        _evaluation!['patientScore'] is num ? (_evaluation!['patientScore'] as num).toDouble() : null;
    final patientComment = _evaluation!['patientComment'] as String? ?? '';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHero(totalScore),
        _buildRadarChart(scores),
        if (strengths.isNotEmpty)
          _buildFeedbackBlock('主要优点', AppColors.primaryOf(context), true, strengths),
        if (improvements.isNotEmpty)
          _buildFeedbackBlock('优先改进点', AppColors.vermilionOf(context), false, improvements),
        if (finalReport.isNotEmpty) _buildFinalReport(finalReport),
        if (patientComment.isNotEmpty || patientScore != null)
          _buildPatientFeedback(patientScore, patientComment),
        const SizedBox(height: 30),
      ],
    );
  }

  Future<void> _retryArchive() async {
    final id = _sessionId;
    if (id == null || _isRetrying) return;
    setState(() => _isRetrying = true);
    final ok = await StudentService().retrySessionArchive(id);
    if (!mounted) return;
    if (ok) {
      await _loadEvaluation();
    } else {
      setState(() => _isRetrying = false);
      AppFeedback.error(context, '评估仍未完成，请稍后再试');
    }
  }

  /// 提取 4 维评分（每维 0-25）
  List<({String name, double score, String comment})> _extractScores() {
    final raw = _evaluation?['scores'];
    final comments = _evaluation?['comments'];
    const labels = {
      'history': '病史采集',
      'logic': '诊断逻辑',
      'communication': '沟通技巧',
      'humanity': '人文关怀',
    };
    final result = <({String name, double score, String comment})>[];
    if (raw is! Map) return result;
    for (final key in ['history', 'logic', 'communication', 'humanity']) {
      final v = raw[key];
      final score = (v is num ? v.toDouble() : 0.0).clamp(0.0, 25.0);
      String comment = '';
      if (comments is Map) {
        comment = comments[key]?.toString() ?? '';
      }
      result.add((name: labels[key]!, score: score, comment: comment));
    }
    return result;
  }

  double _extractTotalScore() {
    final v = _evaluation?['totalScore'];
    if (v is num) return v.toDouble().clamp(0.0, 100.0);
    // 兜底：4 维相加
    final scores = _extractScores();
    final sum = scores.fold<double>(0, (s, e) => s + e.score);
    return sum.clamp(0.0, 100.0);
  }

  List<String> _extractStringList(String key) {
    final v = _evaluation?[key];
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  Widget _buildHero(double totalScore) {
    final level = _scoreLevel(totalScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryOf(context),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          MonoText(
            '问诊结束 · OSCE 临床考核',
            fontSize: 11,
            color: AppColors.onPrimarySoftOf(context),
            letterSpacing: 0.14,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalScore.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimaryOf(context),
                  height: 1,
                  letterSpacing: -0.04,
                ),
              ),
              Text(
                ' /100',
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.onPrimarySoftOf(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            level,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onPrimaryLightOf(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLevel(double score) {
    if (score >= 90) return '优秀 — 临床胜任力达标';
    if (score >= 75) return '良好 — 接近优秀水平';
    if (score >= 60) return '合格 — 基本掌握要领';
    return '待加强 — 建议复盘重练';
  }

  Widget _buildRadarChart(
      List<({String name, double score, String comment})> scores) {
    if (scores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: _RadarPainter(
                dimensions: scores
                    .map((s) => (name: s.name, score: s.score, maxScore: 25.0))
                    .toList(),
                ruleColor: AppColors.ruleOf(context),
                textColor: AppColors.textOf(context),
                text3Color: AppColors.text3Of(context),
                primaryColor: AppColors.primaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildRadarLegend(scores),
        ],
      ),
    );
  }

  Widget _buildRadarLegend(
      List<({String name, double score, String comment})> scores) {
    final colors = [
      AppColors.chart1,
      AppColors.chart2,
      AppColors.chart3,
      AppColors.chart4,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 16,
        childAspectRatio: 3.5,
      ),
      itemCount: scores.length,
      itemBuilder: (context, i) {
        final s = scores[i];
        final color = colors[i % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border.all(color: AppColors.surfaceEdgeOf(context)),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.name,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.text2Of(context))),
              ),
              Text(
                '${s.score.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackBlock(
      String title, Color color, bool isPositive, List<String> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.check_circle : Icons.error_outline,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              MonoText(title.toUpperCase(),
                  fontSize: 11, color: color, letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: TextStyle(color: color, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.text2Of(context),
                            height: 1.55),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFinalReport(String report) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border.all(color: AppColors.surfaceEdgeOf(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 12, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              MonoText('AI 总结评语',
                  fontSize: 11,
                  color: AppColors.primaryOf(context),
                  letterSpacing: 0.1),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: _parseRichText(report),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text2Of(context),
                height: 1.6,
              ),
            ),
          ),
          const AiGeneratedNote(),
        ],
      ),
    );
  }

  /// 患者(SP)视角的满意度打分与评语（作为学生本次问诊成绩的患者视角补充）
  Widget _buildPatientFeedback(double? patientScore, String patientComment) {
    final score = (patientScore ?? 0.0).clamp(0.0, 100.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.primaryOf(context).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 12, color: AppColors.primaryOf(context)),
              const SizedBox(width: 6),
              MonoText('患者(SP)满意度',
                  fontSize: 11,
                  color: AppColors.primaryOf(context),
                  letterSpacing: 0.1),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(0)} /100',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
            ],
          ),
          if (patientComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: _parseRichText(patientComment),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.text2Of(context),
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _parseRichText(String text) {
    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int start = 0;
    for (final match in boldRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }
}

/// 雷达图 Painter（支持任意维度，按 maxScore 归一化）
class _RadarPainter extends CustomPainter {
  final List<({String name, double score, double maxScore})> dimensions;
  final Color ruleColor;
  final Color textColor;
  final Color text3Color;
  final Color primaryColor;

  _RadarPainter({
    required this.dimensions,
    required this.ruleColor,
    required this.textColor,
    required this.text3Color,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dimensions.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.4;

    final n = dimensions.length;
    final angleStep = 2 * pi / n;

    // 网格（4 层）
    final gridPaint = Paint()
      ..color = ruleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var level = 1; level <= 4; level++) {
      final r = radius * level / 4;
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

    // 轴线
    final axisPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = 0.6;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + radius * cos(angle), cy + radius * sin(angle)),
        axisPaint,
      );
    }

    // 数据多边形（按 maxScore 归一化到 0-1）
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final ratio = (dimensions[i].score / dimensions[i].maxScore).clamp(0.0, 1.0);
      final r = radius * ratio;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 数据点
    final dotPaint = Paint()..color = primaryColor;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final ratio = (dimensions[i].score / dimensions[i].maxScore).clamp(0.0, 1.0);
      final r = radius * ratio;
      canvas.drawCircle(
        Offset(cx + r * cos(angle), cy + r * sin(angle)),
        4,
        dotPaint,
      );
    }

    // 轴标签 + 分数
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + i * angleStep;
      final labelR = radius + 18;
      final x = cx + labelR * cos(angle);
      final y = cy + labelR * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: dimensions[i].name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));

      // 分数
      final scoreTp = TextPainter(
        text: TextSpan(
          text: '${dimensions[i].score.toStringAsFixed(0)}',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: text3Color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      scoreTp.layout();
      final ratio = (dimensions[i].score / dimensions[i].maxScore).clamp(0.0, 1.0);
      final scoreR = radius * ratio;
      final sx = cx + scoreR * cos(angle);
      final sy = cy + scoreR * sin(angle);
      scoreTp.paint(
          canvas, Offset(sx - scoreTp.width / 2, sy - scoreTp.height - 4));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      ruleColor != old.ruleColor ||
      textColor != old.textColor ||
      text3Color != old.text3Color ||
      primaryColor != old.primaryColor ||
      dimensions.length != old.dimensions.length;
}
