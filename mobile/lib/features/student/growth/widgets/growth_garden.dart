import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../growth_stats.dart';

/// 成长花园 Hero 卡 —— 成长页的情感锚点
///
/// 过去成长页一上来就是「已刷 / 答对 / 答错 / 正确率 / 模块占比」的数字墙，
/// 信息过载、没有情绪。这里改为「一株随真实数据生长的植物 + 一句治愈文案 + 两个关键数字」，
/// 让「成长」被看见，而不是被统计。
///
/// 植物分 5 个阶段（种子 → 萌芽 → 展叶 → 抽枝 → 开花），由累计训练次数与连续天数
/// 共同决定；入场播一次「生长」动画，之后极缓慢呼吸 —— 静，但不死。
class GrowthGardenCard extends StatefulWidget {
  const GrowthGardenCard({super.key, required this.stats});

  final GrowthStats stats;

  @override
  State<GrowthGardenCard> createState() => _GrowthGardenCardState();
}

class _GrowthGardenCardState extends State<GrowthGardenCard>
    with SingleTickerProviderStateMixin {
  /// 呼吸动画：驱动植物光点的明暗起伏（4.2s 一个来回，慢到只是「活着」的暗示）
  late final AnimationController _breathe;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduce) {
      _breathe.value = 0.5;
    } else if (!_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  /// 生长进度 0~1：累计训练为主（65%），连续天数为辅（35%）
  double get _target {
    final s = widget.stats;
    if (s.totalTrainings <= 0) return 0.0;
    final byTotal = (s.totalTrainings / 60.0).clamp(0.0, 1.0);
    final byStreak = (s.streakDays / 30.0).clamp(0.0, 1.0);
    return (byTotal * 0.65 + byStreak * 0.35).clamp(0.10, 1.0);
  }

  /// 阶段名
  String get _stageName {
    final p = _target;
    if (p <= 0.001) return '一颗种子';
    if (p < 0.25) return '萌芽';
    if (p < 0.55) return '展叶';
    if (p < 0.85) return '抽枝';
    return '开花';
  }

  /// 治愈文案：不报数字，只说状态
  ///
  /// 每行控制在 8 个汉字以内 —— Hero 左侧文案栏在 360dp 屏上只有约 186dp，
  /// 超长会挤成三行、把卡片撑高，反而破坏「克制」的观感。
  String get _whisper {
    final s = widget.stats;
    if (s.totalTrainings <= 0) return '今天，\n种下第一颗种子';
    if (s.streakDays <= 0) return '中断也没关系，\n随时可以浇水';
    if (s.streakDays < 3) return '刚冒出小芽，\n慢慢来，也很好';
    if (s.streakDays < 7) return '小苗正在舒展，\n保持这个节奏';
    if (s.streakDays < 14) return '一周多了，\n习惯在悄悄生根';
    if (s.streakDays < 30) return '根系越来越扎实，\n再晒几天太阳';
    return '你把自己，\n养得很扎实了';
  }

  /// 副文案：给一个「再一步」的具体目标，而不是又一组统计
  String get _hint {
    final s = widget.stats;
    if (s.totalTrainings <= 0) return '完成一次训练，它就会发芽';
    const marks = [3, 7, 14, 30, 60, 100];
    for (final m in marks) {
      if (s.streakDays < m) return '再坚持 ${m - s.streakDays} 天，就满 $m 天了';
    }
    return '历史最长连续 ${s.longestStreakDays} 天';
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primaryOf(context);
    final surface = AppColors.surfaceOf(context);
    final top = Color.lerp(surface, primary, 0.17)!;
    final mid = Color.lerp(surface, AppColors.indigoOf(context), 0.07)!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, mid, surface],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.9),
        ),
        boxShadow: AppShadow.card(context),
      ),
      child: Stack(
        children: [
          // 右上角同心弧 + 光晕：与首页氛围层同一套语言，但更轻
          Positioned.fill(
            child: CustomPaint(
              painter: _GardenBackdropPainter(
                glow: primary,
                arc: AppColors.indigoOf(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stageChip(context),
                      const SizedBox(height: 10),
                      Text(
                        _whisper,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: -0.2,
                          color: AppColors.textOf(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hint,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.text3Of(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SeedStat(
                              value: widget.stats.streakDays,
                              unit: '天',
                              label: '连续',
                            ),
                          ),
                          Expanded(
                            child: _SeedStat(
                              value: widget.stats.totalTrainings,
                              unit: '次',
                              label: '累计训练',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // 植物：随数据生长
                AnimatedBuilder(
                  animation: _breathe,
                  builder: (context, _) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: _target),
                      duration: _reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, p, _) {
                        return CustomPaint(
                          size: const Size(96, 128),
                          painter: GrowthPlantPainter(
                            progress: p,
                            sparkle: _breathe.value,
                            stem: AppColors.moss3Of(context),
                            leaf: primary,
                            leafDeep: Color.lerp(primary, AppColors.moss3Of(context), 0.5)!,
                            petal: AppColors.amberOf(context),
                            soil: AppColors.paper3Of(context),
                            glow: primary,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageChip(BuildContext context) {
    final c = AppColors.primaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_rounded, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            _stageName,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阶段数字 —— 大字号 + 单位 + 标签，滚动入场
class _SeedStat extends StatelessWidget {
  const _SeedStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  final int value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: AppColors.text4Of(context)),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${v.round()}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.5,
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: kCjkMonoFallback,
                    color: AppColors.textOf(context),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text3Of(context),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 花园背景装饰：底部柔光 + 右上同心弧
class _GardenBackdropPainter extends CustomPainter {
  const _GardenBackdropPainter({required this.glow, required this.arc});

  final Color glow;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    // 右下柔光：托住植物，让它不像贴在白纸上
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.78),
      size.width * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.82, size.height * 0.78),
          size.width * 0.42,
          [
            glow.withValues(alpha: 0.13),
            glow.withValues(alpha: 0.04),
            glow.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 右上同心弧
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = arc.withValues(alpha: 0.16);
    final center = Offset(size.width * 1.02, -size.height * 0.10);
    for (var i = 0; i < 3; i++) {
      final r = size.width * (0.24 + i * 0.085);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), math.pi * 0.60,
          math.pi * 0.55, false, paint,);
    }
  }

  @override
  bool shouldRepaint(covariant _GardenBackdropPainter old) =>
      glow != old.glow || arc != old.arc;
}

/// 成长植物插画
///
/// 纯 Canvas 绘制（不引入图片、不增包体）：土丘 → 茎（二次贝塞尔）→ 对生叶片 → 花。
/// [progress] 0~1 决定株高、叶片数量与是否开花，[sparkle] 驱动周围光点呼吸。
class GrowthPlantPainter extends CustomPainter {
  const GrowthPlantPainter({
    required this.progress,
    required this.stem,
    required this.leaf,
    required this.leafDeep,
    required this.petal,
    required this.soil,
    required this.glow,
    this.sparkle = 0.5,
  });

  final double progress;
  final Color stem;
  final Color leaf;
  final Color leafDeep;
  final Color petal;
  final Color soil;
  final Color glow;

  /// 呼吸相位 0~1
  final double sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final groundY = h * 0.86;
    final p = progress.clamp(0.0, 1.0);

    // ---- 土丘：一条柔和的曲线，清新而不抢戏 ----
    //
    // 控制点抬到 groundY 之上 0.16h，使丘顶（贝塞尔 t=0.5 处）略高于 groundY，
    // 茎的起点才会「埋进土里」而不是悬在丘面上。
    final mound = Path()
      ..moveTo(cx - w * 0.38, h)
      ..quadraticBezierTo(cx, groundY - h * 0.16, cx + w * 0.38, h)
      ..close();
    canvas.drawPath(mound, Paint()..color = soil.withValues(alpha: 0.55));

    // ---- 光点：呼吸感的来源 ----
    const dots = [
      Offset(0.14, 0.34),
      Offset(0.88, 0.26),
      Offset(0.78, 0.56),
    ];
    for (var i = 0; i < dots.length; i++) {
      final phase = (sparkle + i * 0.33) % 1.0;
      final a = (0.14 + 0.20 * math.sin(phase * math.pi)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(w * dots[i].dx, h * dots[i].dy),
        w * (0.020 + i * 0.004),
        Paint()..color = glow.withValues(alpha: a),
      );
    }

    if (p <= 0.001) {
      // 还没开始：土里躺着一颗种子
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, groundY - h * 0.012),
            width: w * 0.10,
            height: w * 0.07,),
        Paint()..color = stem.withValues(alpha: 0.85),
      );
      return;
    }

    // ---- 茎 ----
    final stemH = h * 0.62 * (0.16 + 0.84 * p);
    final p0 = Offset(cx, groundY + 1);
    final p1 = Offset(cx - w * 0.10, groundY - stemH * 0.55);
    final p2 = Offset(cx + w * 0.07, groundY - stemH);

    canvas.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.042
        ..strokeCap = StrokeCap.round
        ..color = stem,
    );

    Offset onStem(double t) {
      final u = 1 - t;
      return Offset(
        u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
        u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
      );
    }

    // ---- 对生叶片：自下而上变小，越低越深 ----
    final leafCount = (1 + (p * 5).round()).clamp(2, 6).toInt();
    for (var i = 0; i < leafCount; i++) {
      final t = leafCount == 1 ? 0.55 : 0.28 + 0.58 * (i / (leafCount - 1));
      final base = onStem(t);
      final side = i.isEven ? -1.0 : 1.0;
      final len = w * 0.30 * (1.0 - 0.34 * t) * (0.5 + 0.5 * p);
      final tip = Offset(base.dx + side * len, base.dy - len * 0.44);

      final blade = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx + side * len * 0.40, base.dy - len * 0.66,
            tip.dx, tip.dy,)
        ..quadraticBezierTo(
            base.dx + side * len * 0.54, base.dy + len * 0.12, base.dx, base.dy,)
        ..close();
      canvas.drawPath(
          blade, Paint()..color = (i < 2 ? leafDeep : leaf).withValues(alpha: 0.92),);
    }

    // ---- 花：抽枝期结苞，成熟期开五瓣 ----
    if (p >= 0.82) {
      const petals = 5;
      final r = w * 0.082;
      for (var i = 0; i < petals; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / petals;
        canvas.drawCircle(
          Offset(p2.dx + math.cos(a) * r * 0.92, p2.dy + math.sin(a) * r * 0.92),
          r * 0.66,
          Paint()..color = petal.withValues(alpha: 0.82),
        );
      }
      canvas.drawCircle(p2, r * 0.46, Paint()..color = petal);
    } else if (p >= 0.58) {
      canvas.drawOval(
        Rect.fromCenter(center: p2, width: w * 0.075, height: w * 0.10),
        Paint()..color = petal.withValues(alpha: 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GrowthPlantPainter old) =>
      progress != old.progress ||
      sparkle != old.sparkle ||
      stem != old.stem ||
      leaf != old.leaf ||
      leafDeep != old.leafDeep ||
      petal != old.petal ||
      soil != old.soil ||
      glow != old.glow;
}
