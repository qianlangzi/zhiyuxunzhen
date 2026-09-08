import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'guide_anchor.dart';
import 'guide_controller.dart';
import 'guide_gesture.dart';
import 'guide_models.dart';

/// 新手指引 · 聚焦高亮层
///
/// 视觉语言与项目一致（磨砂玻璃 + 柔光）：
///   · 全屏暗化 + 目标控件挖洞，**不画任何实线描边**，只用多层柔光把硬边藏起来
///   · 说明卡是真·毛玻璃（BackdropFilter），无边框，只靠阴影与顶部极淡高光分层
///   · 洞口位置每帧 lerp 跟随；卡片淡入 + 轻微上浮，节奏放慢求「柔滑」
///
/// 挂在 [MaterialApp] 的 builder 里，覆盖包括 push 页在内的整屏。
class GuideOverlay extends ConsumerStatefulWidget {
  const GuideOverlay({super.key});

  @override
  ConsumerState<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends ConsumerState<GuideOverlay>
    with TickerProviderStateMixin {
  /// 柔光呼吸（放慢到 2.6s，避免急促闪烁）
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// 卡片入场
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..value = 1;

  Rect? _curRect;
  double _holeAlpha = 0;
  String? _stepKey;

  @override
  void dispose() {
    _pulse.dispose();
    _card.dispose();
    super.dispose();
  }

  void _syncHole(Rect? target) {
    if (target == null) {
      _holeAlpha = (_holeAlpha - 0.10).clamp(0.0, 1.0);
      return;
    }
    _holeAlpha = (_holeAlpha + 0.10).clamp(0.0, 1.0);
    if (_curRect == null || _holeAlpha < 0.12) {
      _curRect = target;
    } else {
      _curRect = Rect.lerp(_curRect, target, 0.18);
    }
  }

  void _playCardEntrance(String key) {
    if (_stepKey == key) return;
    _stepKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _card.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guideControllerProvider);
    final step = state.current;
    if (!state.active || step == null) {
      _stepKey = null;
      return const SizedBox.shrink();
    }

    final tour = state.tour!;
    _playCardEntrance('${tour.id}#${state.step}');

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // 每帧重测锚点：滚动 / 懒加载 / 转场时洞都能平滑跟住
        _syncHole(GuideAnchorRegistry.rectOf(step.anchor));
        return _buildLayer(context, state, step);
      },
    );
  }

  Widget _buildLayer(BuildContext context, GuideState state, GuideStep step) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final controller = ref.read(guideControllerProvider.notifier);
    final primary = AppColors.primaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hole = (_curRect != null && _holeAlpha > 0.05) ? _curRect! : null;
    final estH = step.hasGesture ? 252.0 : 206.0;

    double? top;
    double? bottom;
    bool below = true;
    if (hole != null) {
      if (hole.center.dy >= size.height * 0.52) {
        bottom = size.height - hole.top + 16;
        below = false;
      } else {
        top = hole.bottom + 16;
        below = true;
      }
      top = top == null
          ? null
          : _clamp(
              top, padding.top + 12, size.height - padding.bottom - estH - 12);
      bottom = bottom == null
          ? null
          : _clamp(
              bottom, padding.bottom + 12, size.height - padding.top - estH - 12);
    }

    final card = AnimatedBuilder(
      animation: _card,
      builder: (context, child) {
        final v = Curves.easeOutQuart.transform(_card.value);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 20),
            child: Transform.scale(
              scale: 0.95 + 0.05 * v,
              alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: _buildGlassCard(context, state, step, primary),
    );

    final Widget positionedCard;
    if (hole == null) {
      positionedCard = Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: card,
          ),
        ),
      );
    } else if (below) {
      positionedCard = Positioned(
        top: top,
        left: 20,
        right: 20,
        child: card,
      );
    } else {
      positionedCard = Positioned(
        bottom: bottom,
        left: 20,
        right: 20,
        child: card,
      );
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.next,
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    rect: _curRect,
                    alpha: _holeAlpha,
                    pulse: _pulse.value,
                    circle: step.circle,
                    glow: primary,
                    mask: Colors.black.withValues(alpha: isDark ? 0.68 : 0.58),
                  ),
                ),
              ),
            ),
          ),
          positionedCard,
        ],
      ),
    );
  }

  double _clamp(double v, double min, double max) =>
      max < min ? min : v.clamp(min, max);

  // ---------------- 毛玻璃说明卡 ----------------

  Widget _buildGlassCard(
    BuildContext context,
    GuideState state,
    GuideStep step,
    Color primary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.surfaceOf(context);
    final isLast = state.step == state.tour!.steps.length - 1;
    final controller = ref.read(guideControllerProvider.notifier);

    const shape = BorderRadius.only(
      topLeft: Radius.circular(26),
      topRight: Radius.circular(8),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(26),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.20),
            blurRadius: 48,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surface.withValues(alpha: isDark ? 0.80 : 0.88),
                  surface.withValues(alpha: isDark ? 0.64 : 0.74),
                ],
              ),
            ),
            child: Stack(
              children: [
                // 顶部极淡高光：给玻璃一点「厚度」，不是线
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.06 : 0.15),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 15, 13),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...List.generate(state.tour!.steps.length, (i) {
                            final on = i == state.step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 340),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(right: 5),
                              width: on ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: on
                                    ? primary
                                    : AppColors.text4Of(context)
                                        .withValues(alpha: 0.32),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                          if (step.tag != null) ...[
                            const SizedBox(width: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.amberOf(context)
                                    .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                step.tag!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.amberOf(context),
                                  letterSpacing: 0.03,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: controller.skip,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Text(
                                '跳过',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.text4Of(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          letterSpacing: -0.01,
                          color: AppColors.textOf(context),
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (step.hasGesture)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GuideGestureDemo(gesture: step.gesture),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step.desc,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.62,
                                  color: AppColors.text2Of(context),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          step.desc,
                          style: TextStyle(
                            fontSize: 12.8,
                            height: 1.68,
                            color: AppColors.text2Of(context),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          PressableScale(
                            child: GestureDetector(
                              onTap: controller.next,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 9),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isLast ? '知道了' : '下一步',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.02,
                                        color: AppColors.onPrimaryOf(context),
                                      ),
                                    ),
                                    if (!isLast) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 15,
                                        color: AppColors.onPrimaryOf(context),
                                      ),
                                    ],
                                  ],
                                ),
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
          ),
        ),
      ),
    );
  }
}

/// 挖洞遮罩 + 柔光（**无实线描边**）
///
/// 旧版在洞口画了 1.6px 实线，而目标控件（教案卡 / 班级卡）本身就带边框，
/// 两圈线叠在一起看着就是「下划线」。改为：外侧用大模糊晕开，内侧裁到洞里
/// 刷一层柔光把剪切硬边藏起来 —— 既聚焦，又没有任何线。
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.rect,
    required this.alpha,
    required this.pulse,
    required this.circle,
    required this.glow,
    required this.mask,
  });

  final Rect? rect;
  final double alpha;
  final double pulse;
  final bool circle;
  final Color glow;
  final Color mask;

  static const double _pad = 7.0;
  static const double _radius = 18.0;

  RRect get _rRect {
    final r = rect!.inflate(_pad);
    if (circle) {
      final radius = math.max(r.width, r.height) / 2;
      return RRect.fromRectAndRadius(
        Rect.fromCircle(center: r.center, radius: radius),
        Radius.circular(radius),
      );
    }
    return RRect.fromRectAndRadius(
      r,
      Radius.circular(math.min(_radius, math.min(r.width, r.height) / 2)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (rect == null || alpha <= 0.01) {
      canvas.drawPath(full, Paint()..color = mask);
      return;
    }

    final hole = _rRect;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        full,
        Path()..addRRect(hole),
      ),
      Paint()..color = mask,
    );

    // ① 外侧柔光：大模糊，向暗化区域晕开
    canvas.drawRRect(
      hole.inflate(1.5 + pulse * 2.5),
      Paint()
        ..color = glow.withValues(alpha: (0.14 + 0.10 * pulse) * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 + pulse * 3
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 18),
    );

    // ② 内侧柔光：裁到洞内，柔化剪切硬边
    canvas.save();
    canvas.clipPath(Path()..addRRect(hole), doAntiAlias: true);
    canvas.drawRRect(
      hole.deflate(1),
      Paint()
        ..color = glow.withValues(alpha: (0.16 + 0.12 * pulse) * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13 + pulse * 5
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => true;
}
