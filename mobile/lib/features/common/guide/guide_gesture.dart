import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'guide_models.dart';

/// 手势演示动画 —— 用循环动画把「看不见的交互」演出来
///
/// 新手引导里最难讲清楚的就是长按、拖动、双指缩放这类隐藏手势，
/// 文字描述再详细也不如演一遍。这里用 CustomPainter 画一个简化手指 +
/// 被操作的对象（卡片 / 图片 / 弹层 / 列表），配合 1.9 秒循环动画。
class GuideGestureDemo extends StatefulWidget {
  const GuideGestureDemo({
    super.key,
    required this.gesture,
    this.width = 88,
    this.height = 74,
  });

  final GuideGesture gesture;
  final double width;
  final double height;

  @override
  State<GuideGestureDemo> createState() => _GuideGestureDemoState();
}

class _GuideGestureDemoState extends State<GuideGestureDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _GesturePainter(
            gesture: widget.gesture,
            t: _controller.value,
            color: AppColors.primaryOf(context),
            hint: AppColors.text3Of(context),
          ),
        ),
      ),
    );
  }
}

class _GesturePainter extends CustomPainter {
  const _GesturePainter({
    required this.gesture,
    required this.t,
    required this.color,
    required this.hint,
  });

  final GuideGesture gesture;
  final double t;
  final Color color;
  final Color hint;

  /// 循环动画里的「移动段」：前 16% 停顿，中间 62% 移动，后 22% 停顿
  double get _move => Curves.easeInOutCubic.transform(
        ((t - 0.16) / 0.62).clamp(0.0, 1.0),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    switch (gesture) {
      case GuideGesture.none:
        break;
      case GuideGesture.tap:
        _paintTap(canvas, size, c);
      case GuideGesture.longPress:
        _paintLongPress(canvas, size, c);
      case GuideGesture.drag:
        _paintDrag(canvas, size, c);
      case GuideGesture.swipeLeft:
      case GuideGesture.swipeRight:
        _paintSwipe(
          canvas,
          size,
          c,
          toLeft: gesture == GuideGesture.swipeLeft,
        );
      case GuideGesture.pinch:
        _paintPinch(canvas, size, c);
      case GuideGesture.sheetDrag:
        _paintSheetDrag(canvas, size, c);
      case GuideGesture.pullDown:
        _paintPullDown(canvas, size, c);
    }
  }

  @override
  bool shouldRepaint(covariant _GesturePainter oldDelegate) => true;

  // ---------------- 基础绘制 ----------------

  /// 简化手指：一个圆角胶囊 + 顶端圆头
  void _finger(
    Canvas canvas,
    Offset tip, {
    double s = 1.0,
    double rotate = 0.0,
  }) {
    final paint = Paint()..color = color.withValues(alpha: 0.92);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(rotate);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 13 * s), width: 13 * s, height: 26 * s),
      Radius.circular(6.5 * s),
    );
    canvas.drawRRect(body, paint);
    canvas.drawRRect(body, edge);
    canvas.drawCircle(Offset.zero, 7.5 * s, paint);
    canvas.drawCircle(Offset.zero, 7.5 * s, edge);
    canvas.restore();
  }

  /// 被操作对象的虚影卡片
  void _ghost(
    Canvas canvas,
    Rect rect, {
    double alpha = 0.16,
    double radius = 8,
  }) {
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(r, Paint()..color = hint.withValues(alpha: alpha));
    canvas.drawRRect(
      r,
      Paint()
        ..color = hint.withValues(alpha: alpha + 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  /// 箭头（V 形）
  void _chevron(
    Canvas canvas,
    Offset p,
    double s,
    double angle,
    Color c,
    double alpha,
  ) {
    final paint = Paint()
      ..color = c.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(-s, -s * 0.6)
      ..lineTo(0, s * 0.6)
      ..lineTo(s, -s * 0.6);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  // ---------------- 各类手势 ----------------

  /// 轻点：手指轻微下压 + 持续扩散的水波
  void _paintTap(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0;
      final r = 7 + phase * base * 0.34;
      final a = (1 - phase) * 0.42;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
    final press = (math.sin(t * 2 * math.pi) + 1) / 2;
    _finger(canvas, c + Offset(0, -base * 0.10 + press * 5), s: 0.92);
  }

  /// 长按：手指不动，周围进度环走满一圈（约 2 秒）
  void _paintLongPress(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    final r = base * 0.32;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = hint.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    _finger(canvas, c, s: 0.94);
  }

  /// 拖动：卡片随手指上下移动，右侧带排序手柄
  void _paintDrag(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.46;
    final h = size.height * 0.24;
    final dy = (_move - 0.5) * size.height * 0.44;
    final rect = Rect.fromCenter(
      center: c + Offset(-size.width * 0.08, dy),
      width: w,
      height: h,
    );
    _ghost(canvas, rect, alpha: 0.18);
    // 排序手柄（三横杠）
    final handleX = rect.right - 9;
    final hp = Paint()
      ..color = hint.withValues(alpha: 0.75)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = rect.center.dy - 4.0 + i * 4.0;
      canvas.drawLine(Offset(handleX - 3, y), Offset(handleX + 3, y), hp);
    }
    // 上下方向提示
    final arrowA = math.sin(_move * math.pi) * 0.7;
    _chevron(canvas, Offset(rect.left + 11, rect.top - 7), 4, math.pi, hint, arrowA);
    _chevron(canvas, Offset(rect.left + 11, rect.bottom + 7), 4, 0, hint, arrowA);
    _finger(canvas, rect.center + const Offset(0, 2), s: 0.86);
  }

  /// 侧滑：内容横移，同时另一侧滑出面板
  void _paintSwipe(
    Canvas canvas,
    Size size,
    Offset c, {
    required bool toLeft,
  }) {
    final dir = toLeft ? -1.0 : 1.0;
    final w = size.width * 0.60;
    final h = size.height * 0.30;
    final dx = dir * (_move - 0.5) * size.width * 0.42;
    final rect = Rect.fromCenter(
      center: c + Offset(dx * 0.55 - dir * size.width * 0.06, 0),
      width: w,
      height: h,
    );
    _ghost(canvas, rect, alpha: 0.15);

    // 反向滑出的托盘
    final trayW = size.width * 0.22;
    final trayRect = Rect.fromLTWH(
      toLeft ? size.width - trayW * _move - 2 : -trayW * (1 - _move) + 2,
      c.dy - h * 0.62,
      trayW,
      h * 1.24,
    );
    _ghost(canvas, trayRect, alpha: 0.20 * _move, radius: 7);

    final arrowA = math.sin(_move * math.pi);
    _chevron(
      canvas,
      Offset(c.dx + dir * size.width * 0.16, c.dy + h * 0.5 + 9),
      5,
      toLeft ? -math.pi / 2 : math.pi / 2,
      color,
      arrowA * 0.9,
    );
    _finger(canvas, c + Offset(dir * size.width * 0.30 - dir * _move * size.width * 0.28, 4), s: 0.86);
  }

  /// 双指缩放：两指张开，画面同步放大
  void _paintPinch(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    final d = ui.lerpDouble(base * 0.16, base * 0.40, _move)!;
    final side = ui.lerpDouble(base * 0.34, base * 0.62, _move)!;
    _ghost(
      canvas,
      Rect.fromCenter(center: c, width: side, height: side * 0.86),
      alpha: 0.14,
      radius: 10,
    );
    _finger(canvas, c + Offset(-d, -d * 0.55), s: 0.8, rotate: -0.28);
    _finger(canvas, c + Offset(d, d * 0.55), s: 0.8, rotate: -0.28 + math.pi);
  }

  /// 底部弹层下拉关闭
  void _paintSheetDrag(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.70;
    final h = size.height * 0.34;
    final dy = _move * size.height * 0.26;
    final rect = Rect.fromLTWH(
      c.dx - w / 2,
      size.height - h - 2 + dy,
      w,
      h,
    );
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(r, Paint()..color = hint.withValues(alpha: 0.18));
    canvas.drawRRect(
      r,
      Paint()
        ..color = hint.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // 顶部抓手条
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.center.dx, rect.top + 8),
          width: 22,
          height: 3.5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );
    final arrowA = math.sin(_move * math.pi);
    _chevron(
      canvas,
      Offset(rect.center.dx, rect.top - 8),
      5,
      0,
      color,
      arrowA * 0.9,
    );
    _finger(canvas, Offset(rect.center.dx, rect.top + 26), s: 0.84);
  }

  /// 下拉刷新：列表下拉 + 顶部转圈
  void _paintPullDown(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.62;
    final rowH = size.height * 0.12;
    final dy = _move * size.height * 0.26;
    for (var i = 0; i < 3; i++) {
      _ghost(
        canvas,
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - rowH + i * (rowH + 5) + dy),
          width: w,
          height: rowH * 0.72,
        ),
        alpha: 0.14,
        radius: 6,
      );
    }
    final spinR = size.height * 0.11;
    final spinC = Offset(c.dx, size.height * 0.14);
    canvas.drawArc(
      Rect.fromCircle(center: spinC, radius: spinR),
      t * 2 * math.pi * 2,
      math.pi * 1.35,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35 + 0.55 * _move)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    _finger(canvas, c + Offset(0, dy + 2), s: 0.84);
  }
}
