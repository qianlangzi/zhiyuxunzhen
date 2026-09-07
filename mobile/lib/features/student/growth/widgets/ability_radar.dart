import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../../shared/widgets/paper_surfaces.dart';
import '../growth_stats.dart';

/// 能力画像卡 —— 用一张雷达图替掉过去的六条进度条
///
/// 六条横条 = 六组「标签 + 轨道 + 数字」，是后台看板的语言，放在成长页太重。
/// 雷达图一次成型：形状本身就是记忆点（哪块「瘪」一眼可见），
/// 顶点只放两字短标签，具体分数与强弱对比收到下方一行，画面立刻安静下来。
class AbilityRadarCard extends StatelessWidget {
  const AbilityRadarCard({super.key, required this.stats});

  final GrowthStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final accent = AppColors.indigoOf(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final weakest = stats.weakest;
    final strongest = stats.strongest;

    return PaperCard(
      tint: accent,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientIconBadge(
                icon: Icons.radar_rounded,
                color: accent,
                size: 30,
                iconSize: 16,
              ),
              const SizedBox(width: 9),
              Text(
                '能力画像',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOf(context),
                ),
              ),
              const Spacer(),
              Text(
                '综合 ${stats.osceAvg.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: kCjkMonoFallback,
                  color: AppColors.text3Of(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 雷达图：从中心「张开」入场，灵动但不喧闹
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                return CustomPaint(
                  size: const Size(240, 196),
                  painter: _RadarPainter(
                    entries: entries,
                    progress: t,
                    grid: AppColors.ruleOf(context),
                    area: accent,
                    stroke: accent,
                    labelColor: AppColors.text3Of(context),
                    weakestColor: stats.colorOf(context, weakest?.score ?? 100),
                    weakestKey: weakest?.key,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (strongest != null)
                Expanded(
                  child: _ExtremeChip(
                    icon: Icons.trending_up_rounded,
                    caption: '最拿手',
                    name: strongest.label,
                    score: strongest.score,
                    color: AppColors.primaryOf(context),
                  ),
                ),
              if (strongest != null && weakest != null) const SizedBox(width: 10),
              if (weakest != null)
                Expanded(
                  child: _ExtremeChip(
                    icon: Icons.trending_down_rounded,
                    caption: '待加强',
                    name: weakest.label,
                    score: weakest.score,
                    color: stats.colorOf(context, weakest.score),
                    onTap: () => context.pushNamed(RouteNames.recommendation),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtremeChip extends StatelessWidget {
  const _ExtremeChip({
    required this.icon,
    required this.caption,
    required this.name,
    required this.score,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String caption;
  final String name;
  final double score;
  final Color color;

  /// 非空时可点击下钻（当前用于「待加强」→ 薄弱点推荐页补练）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  style: TextStyle(
                      fontSize: 9.5, color: AppColors.text4Of(context),),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2Of(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: kCjkMonoFallback,
              color: color,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: AppColors.text4Of(context),),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: chip,
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.entries,
    required this.progress,
    required this.grid,
    required this.area,
    required this.stroke,
    required this.labelColor,
    required this.weakestColor,
    this.weakestKey,
  });

  final List<AbilityEntry> entries;
  final double progress;

  final Color grid;
  final Color area;
  final Color stroke;
  final Color labelColor;

  /// 最弱维度的顶点单独着色，让「要补哪儿」一眼定位
  final Color weakestColor;
  final String? weakestKey;

  @override
  void paint(Canvas canvas, Size size) {
    final n = entries.length;
    if (n < 3) return;

    final center = Offset(size.width / 2, size.height / 2 + 2);
    final radius = math.min(size.width, size.height) / 2 - 28;

    Offset vertex(int i, double r) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
    }

    // ---- 网格：三层同心多边形 + 轴线 ----
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = grid.withValues(alpha: 0.55);
    for (final level in [0.36, 0.68, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final pt = vertex(i, radius * level);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, radius), gridPaint);
    }

    // ---- 数据面 ----
    final t = progress.clamp(0.0, 1.0);
    final dataPath = Path();
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final ratio = (entries[i].score / 100).clamp(0.0, 1.0) * t;
      final pt = vertex(i, radius * (0.08 + 0.92 * ratio));
      pts.add(pt);
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [area.withValues(alpha: 0.26), area.withValues(alpha: 0.10)],
        ),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = stroke.withValues(alpha: 0.85),
    );

    // ---- 顶点 ----
    for (var i = 0; i < n; i++) {
      final isWeak = entries[i].key == weakestKey;
      final c = isWeak ? weakestColor : stroke;
      canvas.drawCircle(pts[i], isWeak ? 4.0 : 3.0, Paint()..color = c);
      canvas.drawCircle(
        pts[i],
        isWeak ? 7.0 : 5.5,
        Paint()..color = c.withValues(alpha: 0.22),
      );
    }

    // ---- 短标签 ----
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      final lr = radius + 15;
      final pos = Offset(center.dx + math.cos(a) * lr, center.dy + math.sin(a) * lr);
      final tp = TextPainter(
        text: TextSpan(
          text: entries[i].shortLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: entries[i].key == weakestKey ? weakestColor : labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 依据方位调整锚点，避免标签压到图形上
      final dx = -tp.width / 2 - math.cos(a) * tp.width * 0.18;
      final dy = -tp.height / 2 - math.sin(a) * tp.height * 0.30;
      tp.paint(canvas, Offset(pos.dx + dx, pos.dy + dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      progress != old.progress ||
      entries != old.entries ||
      grid != old.grid ||
      area != old.area ||
      stroke != old.stroke ||
      labelColor != old.labelColor ||
      weakestColor != old.weakestColor ||
      weakestKey != old.weakestKey;
}
