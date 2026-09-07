import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'guide_anchor.dart';
import 'guide_controller.dart';
import 'guide_gesture.dart';
import 'guide_models.dart';

/// 新手指引 · 聚焦高亮遮罩层
///
/// 挂在 [MaterialApp] 的 builder 里（覆盖包括 push 页在内的全屏），
/// 由 [guideControllerProvider] 驱动：
///   · 全屏半透明遮罩 + 目标控件「挖洞」
///   · 洞口呼吸光晕，位置每帧平滑跟随（页面滚动 / 布局变化时不会飘）
///   · 说明卡片自动落在洞的上方或下方，带指向小三角
///   · 点遮罩任意处 = 下一步
class GuideOverlay extends ConsumerStatefulWidget {
  const GuideOverlay({super.key});

  @override
  ConsumerState<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends ConsumerState<GuideOverlay>
    with TickerProviderStateMixin {
  /// 光晕呼吸
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  /// 卡片入场
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..value = 1;

  /// 当前绘制的洞（每帧向目标 lerp）
  Rect? _curRect;

  /// 洞的淡入淡出进度（无锚点的概念卡步骤会淡出洞口）
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
      _holeAlpha = (_holeAlpha - 0.14).clamp(0.0, 1.0);
      return;
    }
    _holeAlpha = (_holeAlpha + 0.14).clamp(0.0, 1.0);
    if (_curRect == null || _holeAlpha < 0.15) {
      _curRect = target;
    } else {
      _curRect = Rect.lerp(_curRect, target, 0.22);
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
    final key = '${tour.id}#${state.step}';
    _playCardEntrance(key);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // 每帧重新测量锚点位置：滚动 / 懒加载 / 转场动画中洞都能跟住
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

    final hasHole = _curRect != null && _holeAlpha > 0.05;
    final hole = hasHole ? _curRect! : null;

    // 卡片预估高度（用于安全区钳制）
    final estH = step.hasGesture ? 272.0 : 218.0;

    double? top;
    double? bottom;
    bool below = true;
    if (hole != null) {
      if (hole.center.dy >= size.height * 0.52) {
        bottom = size.height - hole.top + 14;
        below = false;
      } else {
        top = hole.bottom + 14;
        below = true;
      }
      if (top != null) {
        top = _clamp(
          top,
          padding.top + 8,
          size.height - padding.bottom - estH - 8,
        );
      }
      if (bottom != null) {
        bottom = _clamp(
          bottom,
          padding.bottom + 8,
          size.height - padding.top - estH - 8,
        );
      }
    }

    final card = AnimatedBuilder(
      animation: _card,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_card.value);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: child,
          ),
        );
      },
      child: _buildCard(context, state, step, primary),
    );

    Widget positionedCard;
    if (hole == null) {
      positionedCard = Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: card,
          ),
        ),
      );
    } else if (below) {
      positionedCard = Positioned(
        top: top,
        left: 20,
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // stretch：让卡片占满左右 20 边距之间的整宽，避免文字换行导致宽度抖动
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Arrow(
              color: AppColors.surfaceOf(context),
              up: true,
              offset: _arrowOffset(hole, size.width),
            ),
            card,
          ],
        ),
      );
    } else {
      positionedCard = Positioned(
        bottom: bottom,
        left: 20,
        right: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            _Arrow(
              color: AppColors.surfaceOf(context),
              up: false,
              offset: _arrowOffset(hole, size.width),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          // 遮罩（挖洞）—— 点任意处进入下一步
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
                    mask: Colors.black.withValues(alpha: isDark ? 0.72 : 0.64),
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

  double _arrowOffset(Rect hole, double screenW) {
    final cardW = screenW - 40;
    final dx = hole.center.dx - 20 - 9;
    return dx.clamp(16.0, (cardW - 34).clamp(16.0, cardW));
  }

  double _clamp(double v, double min, double max) =>
      max < min ? min : v.clamp(min, max);

  Widget _buildCard(
    BuildContext context,
    GuideState state,
    GuideStep step,
    Color primary,
  ) {
    final isLast = state.step == state.tour!.steps.length - 1;
    final controller = ref.read(guideControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.surfaceEdgeOf(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 13, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // —— 顶部：步骤点 / 角标 / 跳过 ——
          Row(
            children: [
              ...List.generate(state.tour!.steps.length, (i) {
                final on = i == state.step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 5),
                  width: on ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on
                        ? primary
                        : AppColors.text4Of(context).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              if (step.tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoftOf(context),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    step.tag!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.amberOf(context),
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.skip,
                child: Padding(
                  padding: const EdgeInsets.all(4),
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
          const SizedBox(height: 12),

          // —— 标题 ——
          Text(
            step.title,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textOf(context),
            ),
          ),
          const SizedBox(height: 7),

          // —— 说明（有手势时与动画并排，控制卡片高度）——
          if (step.hasGesture)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GuideGestureDemo(gesture: step.gesture),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.desc,
                    style: TextStyle(
                      fontSize: 12.8,
                      height: 1.55,
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
                fontSize: 13.2,
                height: 1.6,
                color: AppColors.text2Of(context),
              ),
            ),

          const SizedBox(height: 12),

          // —— 底部：提示 + 下一步 ——
          Row(
            children: [
              Expanded(
                child: Text(
                  '点击屏幕任意处继续',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.text4Of(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: controller.next,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? '知道了' : '下一步',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimaryOf(context),
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 3),
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
            ],
          ),
        ],
      ),
    );
  }
}

/// 指向高亮区的小三角
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.color,
    required this.up,
    required this.offset,
  });

  final Color color;
  final bool up;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: offset),
      child: CustomPaint(
        size: const Size(18, 9),
        painter: _ArrowPainter(color: color, up: up),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (up) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width / 2, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.up != up;
}

/// 挖洞遮罩 + 呼吸光晕
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

  static const double _pad = 6.0;
  static const double _radius = 16.0;

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
    final maskPath = Path.combine(
      PathOperation.difference,
      full,
      Path()..addRRect(hole),
    );
    canvas.drawPath(maskPath, Paint()..color = mask);

    // 外发光（呼吸）
    final glowAlpha = (0.20 + 0.42 * pulse) * alpha;
    canvas.drawRRect(
      hole.inflate(pulse * 3.5),
      Paint()
        ..color = glow.withValues(alpha: glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + pulse * 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 13),
    );
    // 内圈实描边，保证洞口边界清晰
    canvas.drawRRect(
      hole,
      Paint()
        ..color = glow.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => true;
}
