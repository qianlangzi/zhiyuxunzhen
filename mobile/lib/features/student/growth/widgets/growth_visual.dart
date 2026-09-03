import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../growth_stats.dart';

/// 成长主卡 —— 连续天数环形 + 三项核心指标
///
/// 背景不再是纯色块：底为「主色 → 主色渐变次级」的斜向渐变，
/// 叠加同心弧与两团径向高光（Canvas 绘制，无图片资源），
/// 顶部再压一条内高光，整体是「有色晕的实体卡」而非色块。
class GrowthHeroCard extends StatelessWidget {
  const GrowthHeroCard({
    super.key,
    required this.stats,
    this.masteredCount = 0,
    this.targetDays = 30,
    this.caption,
  });

  final GrowthStats stats;

  /// 错题已掌握数
  final int masteredCount;

  /// 连续天数目标（环形满进度值）
  final int targetDays;

  /// 底部补充文案
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final onPrimary = AppColors.onPrimaryOf(context);
    final ratio = targetDays <= 0
        ? 0.0
        : (stats.streakDays / targetDays).clamp(0.0, 1.0);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.lifted(context),
      ),
      child: Stack(
        children: [
          // ---- 底：斜向渐变 ----
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.moss2,
                    AppColors.moss,
                    primary,
                  ],
                ),
              ),
            ),
          ),
          // ---- 装饰：细网格 + 同心弧 + 径向高光（氛围元素全部并入主卡背景） ----
          Positioned.fill(
            child: CustomPaint(
              painter: _HeroDecorPainter(
                arc: onPrimary,
                glowA: AppColors.amberOf(context),
                glowB: AppColors.indigoOf(context),
                onPrimary: onPrimary,
              ),
            ),
          ),
          // ---- 顶部内高光 ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          // ---- 内容 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RingGauge(
                      value: ratio,
                      size: 92,
                      stroke: 8,
                      colors: [
                        AppColors.heatOf(context, 4).withValues(alpha: 0.85),
                        const Color(0xFFD8E8C8),
                      ],
                      trackColor: onPrimary.withValues(alpha: 0.16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${stats.streakDays}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: kCjkMonoFallback,
                              color: onPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '连续天',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: onPrimary.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatPill(
                              value: '${stats.totalTrainings}',
                              label: '累计训练',
                              onPrimary: true,
                            ),
                          ),
                          Expanded(
                            child: StatPill(
                              value: stats.osceAvg.toStringAsFixed(1),
                              label: 'OSCE 均分',
                              onPrimary: true,
                            ),
                          ),
                          Expanded(
                            child: StatPill(
                              value: '$masteredCount',
                              label: '错题掌握',
                              onPrimary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 1,
                  color: onPrimary.withValues(alpha: 0.14),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caption ??
                            '最长连续 ${stats.longestStreakDays} 天 · 活跃 ${stats.activeDays} 天 · 目标 $targetDays 天',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: onPrimary.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDecorPainter extends CustomPainter {
  const _HeroDecorPainter({
    required this.arc,
    required this.glowA,
    required this.glowB,
    required this.onPrimary,
  });

  final Color arc;
  final Color glowA;
  final Color glowB;
  final Color onPrimary;

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 细网格：氛围层的「病历格」元素并入主卡背景，向下渐隐 ----
    const step = 24.0;
    final gridPaint = Paint()
      ..color = onPrimary.withValues(alpha: 0.055)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ---- 右下同心弧 ----
    final center = Offset(size.width * 0.94, size.height * 1.02);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = arc.withValues(alpha: 0.16);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width * (0.20 + i * 0.13)),
        math.pi,
        math.pi * 0.5,
        false,
        arcPaint,
      );
    }

    // ---- 两团高光 ----
    canvas.drawCircle(
      Offset(size.width * 0.82, -size.height * 0.18),
      size.width * 0.46,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.82, -size.height * 0.18),
          size.width * 0.46,
          [glowA.withValues(alpha: 0.26), glowA.withValues(alpha: 0)],
        ),
    );
    canvas.drawCircle(
      Offset(-size.width * 0.10, size.height * 0.95),
      size.width * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-size.width * 0.10, size.height * 0.95),
          size.width * 0.42,
          [glowB.withValues(alpha: 0.22), glowB.withValues(alpha: 0)],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _HeroDecorPainter old) =>
      arc != old.arc ||
      glowA != old.glowA ||
      glowB != old.glowB ||
      onPrimary != old.onPrimary;
}

/// 能力面板 —— 环形总览 + 五维条形（混合可视化）
///
/// 顶部一枚大环展示综合均分，右侧列出最强 / 最弱维度；
/// 下方五条能力条按升序排列，低于 70 自动转朱砂色并标注「薄弱」。
class AbilityPanel extends StatelessWidget {
  const AbilityPanel({
    super.key,
    required this.stats,
    this.lowThreshold = 70,
  });

  final GrowthStats stats;
  final double lowThreshold;

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final avg = stats.osceAvg;
    final ringColor = stats.colorOf(context, avg);
    final weakest = stats.weakest;
    final strongest = stats.strongest;

    return PaperCard(
      tint: AppColors.amberOf(context),
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.radar_rounded,
                color: AppColors.amberOf(context),
                size: 30,
                iconSize: 16,
              ),
              const SizedBox(width: 9),
              Text(
                '能力评分',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              const Spacer(),
              if (stats.weakCount > 0)
                AppChip(
                  label: '${stats.weakCount} 项薄弱',
                  type: ChipType.vermilion,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RingGauge(
                value: (avg / 100).clamp(0.0, 1.0),
                size: 88,
                stroke: 8,
                colors: [ringColor, ringColor.withValues(alpha: 0.55)],
                trackColor: ringColor.withValues(alpha: 0.13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: kCjkMonoFallback,
                        color: AppColors.textOf(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '综合',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.text4Of(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (strongest != null)
                      _extremeRow(
                        context,
                        icon: Icons.trending_up_rounded,
                        label: '最强',
                        name: strongest.label,
                        score: strongest.score,
                        color: AppColors.primaryOf(context),
                      ),
                    if (strongest != null && weakest != null)
                      const SizedBox(height: 9),
                    if (weakest != null)
                      _extremeRow(
                        context,
                        icon: Icons.trending_down_rounded,
                        label: '最弱',
                        name: weakest.label,
                        score: weakest.score,
                        color: stats.colorOf(context, weakest.score),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 12),
          ...entries.map(
            (e) => AbilityBar(
              label: e.label,
              score: e.score,
              lowThreshold: lowThreshold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _extremeRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String name,
    required double score,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: AppColors.text4Of(context)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.text2Of(context),
            ),
          ),
        ),
        Text(
          score.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: kCjkMonoFallback,
            color: color,
          ),
        ),
      ],
    );
  }
}
