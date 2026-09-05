import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../growth_stats.dart';

/// 训练概览卡 —— 一个焦点（正确率）+ 两个数字（答对 / 答错）
///
/// 精简原则：旧版把「三列清点 + 圆环 + 分段条 + 图例 + 模块占比」全塞在一张卡里，
/// 同一份「答对/答错」信息被表达了三遍。这里只保留一次：
/// 环给直觉（配比），右侧两行给确数，模块占比默认折起、需要再看。
class TrainingOverviewCard extends StatelessWidget {
  const TrainingOverviewCard({
    super.key,
    required this.question,
    this.loading = false,
  });

  /// 刷题统计（答对/答错 + 分模块占比 + 题库总量）
  final QuestionStats question;

  /// 刷题统计是否仍在加载（此时展示骨架，不阻塞其余模块）
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      tint: AppColors.primaryOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.track_changes_rounded,
                color: AppColors.primaryOf(context),
                size: 30,
                iconSize: 16,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '训练概览',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context),
                  ),
                ),
              ),
              if (question.totalCount > 0)
                MonoText(
                  '题库 ${question.totalCount} 题',
                  fontSize: 10.5,
                  color: AppColors.text4Of(context),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            _buildLoading()
          else if (!question.hasData)
            _buildEmpty(context)
          else
            _buildContent(context),
        ],
      ),
    );
  }

  /// 加载中：骨架占位，让「等待」顺滑且不占空间
  Widget _buildLoading() {
    return const Row(
      children: [
        AppSkeleton(width: 92, height: 92, radius: AppRadius.full),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              AppSkeleton(height: 22),
              SizedBox(height: 10),
              AppSkeleton(height: 22, width: 140),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final q = question;
    final frac = q.totalAnswered <= 0 ? 0.0 : (q.correctCount / q.totalAnswered);
    final bankFrac = q.totalCount <= 0
        ? 0.0
        : (q.totalAnswered / q.totalCount).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final base = AppColors.primaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: frac),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return Row(
              children: [
                _AccuracyRing(correct: v, size: 96, stroke: 11),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _countLine(
                        context,
                        label: '答对',
                        value: q.correctCount,
                        color: base,
                      ),
                      const SizedBox(height: 10),
                      _countLine(
                        context,
                        label: '答错',
                        value: q.wrongCount,
                        color: base.withValues(alpha: 0.34),
                      ),
                      if (q.totalCount > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          '已刷 ${q.totalAnswered} · 题库完成 ${(bankFrac * 100).round()}%',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.text4Of(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        if (q.modules.isNotEmpty) ...[
          const SizedBox(height: 8),
          CollapsibleSection(
            title: '分模块占比',
            meta: '${q.modules.length} 个模块',
            initiallyExpanded: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: q.modules.take(6).map((m) => _ModuleRow(stat: m)).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _countLine(
    BuildContext context, {
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.text3Of(context)),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.0,
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: kCjkMonoFallback,
            color: AppColors.textOf(context),
          ),
        ),
      ],
    );
  }

  /// 空态：还没有刷题记录（柔和不发硬块）
  Widget _buildEmpty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.track_changes_rounded,
            size: 28,
            color: AppColors.primaryOf(context).withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            '还没有刷题记录',
            style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)),
          ),
          const SizedBox(height: 3),
          Text(
            '去题库练几道题，攒下第一份战绩',
            style: TextStyle(fontSize: 11, color: AppColors.text4Of(context)),
          ),
        ],
      ),
    );
  }
}

/// 正确率环 —— 单强调色：实色答对 + 同色浅调答错，中心给一个大数字
class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({
    required this.correct,
    this.size = 96,
    this.stroke = 11,
  });

  /// 答对占比 0.0 ~ 1.0
  final double correct;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final correctColor = AppColors.primaryOf(context);
    final pct = ((correct.clamp(0.0, 1.0)) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              correct: correct,
              correctColor: correctColor,
              wrongColor: correctColor.withValues(alpha: 0.18),
              trackColor: correctColor.withValues(alpha: 0.08),
              stroke: stroke,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -0.5,
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: kCjkMonoFallback,
                  color: AppColors.textOf(context),
                ),
              ),
              Text(
                '% 正确率',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.0,
                  color: AppColors.text4Of(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.correct,
    required this.correctColor,
    required this.wrongColor,
    required this.trackColor,
    required this.stroke,
  });

  final double correct;
  final Color correctColor;
  final Color wrongColor;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final f = correct.clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = trackColor);
    if (f > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * f, false,
          paint..color = correctColor,);
    }
    if (f < 1) {
      canvas.drawArc(rect, -math.pi / 2 + math.pi * 2 * f, math.pi * 2 * (1 - f),
          false, paint..color = wrongColor,);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      correct != old.correct ||
      correctColor != old.correctColor ||
      wrongColor != old.wrongColor ||
      trackColor != old.trackColor ||
      stroke != old.stroke;
}

/// 单个模块占比条
class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.stat});

  final ModuleStat stat;

  @override
  Widget build(BuildContext context) {
    final share = stat.share.clamp(0.0, 1.0);
    final barColor = AppColors.primaryOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              stat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: AppColors.text2Of(context)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Container(color: barColor.withValues(alpha: 0.13)),
                    FractionallySizedBox(
                      widthFactor: share,
                      child: Container(color: barColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              '${stat.answered} 题 · ${(share * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: kCjkMonoFallback,
                color: AppColors.text3Of(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
