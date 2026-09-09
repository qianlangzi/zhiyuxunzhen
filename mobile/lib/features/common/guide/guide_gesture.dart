import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'guide_models.dart';

/// 手势演示动画 —— 用循环动画把「看不见的交互」演出来
///
/// 视觉语言（2026-09 重绘版）：
///   · 手指 = 纯色填充指腹（圆头 + 短身 + 顶部高光 + 柔和投影），**绝不描边**
///     —— 旧版描边让指腹看起来像一只鼠标，已废弃。
///   · 被操作对象只用低透明度纯色填充虚影，不描边；
///     轨迹/方向用虚线 + 小箭头表达，克制、干净。
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

  /// 移动段内的钟形包络（起止为 0，中点为 1），给轨迹/箭头做淡入淡出
  double get _bell => math.sin(_move * math.pi);

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

  /// 简化手指：纯色填充的指腹（圆头 + 短身），柔和投影 + 顶部高光
  ///
  /// 铁律：不描边。旧版白色描边在浅色卡上看起来像一只鼠标。
  void _finger(
    Canvas canvas,
    Offset tip, {
    double s = 1.0,
    double rotate = 0.0,
  }) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(rotate);

    // 柔和投影（只投影指尖圆，避免整块发灰）
    canvas.drawCircle(
      const Offset(0, 2),
      6.8 * s,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3),
    );

    final body = Paint()..color = color.withValues(alpha: 0.95);
    // 指身
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 10.5 * s),
          width: 12 * s,
          height: 21 * s,
        ),
        Radius.circular(6 * s),
      ),
      body,
    );
    // 指尖圆头
    canvas.drawCircle(Offset.zero, 6.4 * s, body);
    // 顶部高光：给指腹一点立体感
    canvas.drawCircle(
      Offset(-2 * s, -2.2 * s),
      2 * s,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  /// 被操作对象的虚影：低透明度纯色填充，不描边
  void _ghost(
    Canvas canvas,
    Rect rect, {
    double alpha = 0.13,
    double radius = 9,
    Color? tint,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = (tint ?? color).withValues(alpha: alpha),
    );
  }

  /// 虚线轨迹
  void _dashLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Color c,
    double alpha, {
    double strokeWidth = 1.6,
  }) {
    final paint = Paint()
      ..color = c.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final delta = to - from;
    final len = delta.distance;
    if (len < 1) return;
    final unit = Offset(delta.dx / len, delta.dy / len);
    final dash = 4.0;
    final gap = 4.5;
    double d = 0;
    while (d < len) {
      final end = math.min(d + dash, len);
      canvas.drawLine(from + unit * d, from + unit * end, paint);
      d = end + gap;
    }
  }

  /// 小箭头头部（指向 [tip]，方向由 [dir] 给出）
  void _arrowHead(Canvas canvas, Offset tip, Offset dir, Color c, double alpha,
      {double size = 4.5, double strokeWidth = 2}) {
    if (dir.distance < 0.001) return;
    final unit = Offset(dir.dx / dir.distance, dir.dy / dir.distance);
    final normal = Offset(-unit.dy, unit.dx);
    final paint = Paint()
      ..color = c.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(tip - unit * size + normal * size * 0.7, tip, paint);
    canvas.drawLine(tip - unit * size - normal * size * 0.7, tip, paint);
  }

  // ---------------- 各类手势 ----------------

  /// 轻点：手指轻微下压 + 持续扩散的水波
  void _paintTap(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0;
      final r = 7 + phase * base * 0.32;
      final a = (1 - phase) * 0.36;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    final press = (math.sin(t * 2 * math.pi) + 1) / 2;
    _finger(canvas, c + Offset(0, -base * 0.08 + press * 4.5), s: 0.9);
  }

  /// 长按：手指不动，周围进度环走满一圈（约 2 秒）
  void _paintLongPress(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    final r = base * 0.30;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = hint.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * t,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    // 进度末端小圆点，收尾更精致
    if (t > 0.03 && t < 0.97) {
      final angle = -math.pi / 2 + 2 * math.pi * t;
      canvas.drawCircle(
        Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle)),
        2.4,
        Paint()..color = color,
      );
    }
    _finger(canvas, c, s: 0.92);
  }

  /// 拖动：卡片沿虚线轨道随手指上下移动，右侧带排序手柄
  void _paintDrag(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.52;
    final h = size.height * 0.26;
    final x = c.dx - size.width * 0.03;
    final trackHalf = size.height * 0.32;

    // 虚线轨道 + 上下端点
    _dashLine(
      canvas,
      Offset(x, c.dy - trackHalf),
      Offset(x, c.dy + trackHalf),
      hint,
      0.42,
    );
    for (final dy in [-trackHalf, trackHalf]) {
      canvas.drawCircle(
        Offset(x, c.dy + dy),
        2.2,
        Paint()..color = hint.withValues(alpha: 0.5),
      );
    }

    final dy = (_move - 0.5) * size.height * 0.42;
    final rect = Rect.fromCenter(
      center: Offset(x, c.dy + dy),
      width: w,
      height: h,
    );
    _ghost(canvas, rect);
    // 卡片内容条：两根圆角短条，示意「一张卡片」
    final bar = Paint()..color = hint.withValues(alpha: 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 9, rect.top + 7, w * 0.48, 3.4),
        const Radius.circular(2),
      ),
      bar,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 9, rect.bottom - 11, w * 0.32, 3.4),
        const Radius.circular(2),
      ),
      bar,
    );
    // 排序手柄：两根圆头短横条
    final hp = Paint()
      ..color = hint.withValues(alpha: 0.62)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = rect.center.dy - 2.6 + i * 5.2;
      canvas.drawLine(Offset(rect.right - 11, y), Offset(rect.right - 5, y), hp);
    }
    _finger(canvas, Offset(rect.right - 8, c.dy + dy), s: 0.84);
  }

  /// 侧滑：内容横移，另一侧滑出托盘，下方一条带箭头的虚线轨迹
  void _paintSwipe(
    Canvas canvas,
    Size size,
    Offset c, {
    required bool toLeft,
  }) {
    final dir = toLeft ? -1.0 : 1.0;
    final w = size.width * 0.56;
    final h = size.height * 0.30;
    final dx = dir * (_move - 0.5) * size.width * 0.40;
    final rect = Rect.fromCenter(
      center: c + Offset(dx * 0.6 - dir * size.width * 0.05, 0),
      width: w,
      height: h,
    );
    _ghost(canvas, rect);

    // 反向滑出的托盘（纯填充，随进度浮现）
    final trayW = size.width * 0.20;
    final trayRect = Rect.fromLTWH(
      toLeft ? size.width - trayW * _move - 2 : -trayW * (1 - _move) + 2,
      c.dy - h * 0.62,
      trayW,
      h * 1.24,
    );
    _ghost(canvas, trayRect, alpha: 0.10 + 0.10 * _move, radius: 7,
        tint: hint);
    // 托盘里的两条示意内容
    final tp = Paint()..color = hint.withValues(alpha: 0.32 * _move);
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(trayRect.left + 5, trayRect.top + 10 + i * 12,
              trayRect.width - 10, 4),
          const Radius.circular(2),
        ),
        tp,
      );
    }

    // 下方虚线轨迹 + 箭头
    final ty = c.dy + h * 0.62 + 9;
    _dashLine(
      canvas,
      Offset(c.dx - dir * size.width * 0.24, ty),
      Offset(c.dx + dir * size.width * 0.24, ty),
      color,
      0.30 + 0.25 * _bell,
    );
    _arrowHead(
      canvas,
      Offset(c.dx + dir * size.width * 0.24, ty),
      Offset(dir, 0),
      color,
      0.30 + 0.45 * _bell,
    );

    _finger(
      canvas,
      c + Offset(
        dir * size.width * 0.26 - dir * _move * size.width * 0.26,
        2,
      ),
      s: 0.86,
    );
  }

  /// 双指缩放：两指张开，画面同步放大，两指尖有虚线连接
  void _paintPinch(Canvas canvas, Size size, Offset c) {
    final base = math.min(size.width, size.height);
    final d = ui.lerpDouble(base * 0.15, base * 0.38, _move)!;
    final side = ui.lerpDouble(base * 0.34, base * 0.60, _move)!;
    _ghost(
      canvas,
      Rect.fromCenter(center: c, width: side, height: side * 0.86),
      alpha: 0.10,
      radius: 10,
    );
    // 图片示意：山形折线
    final img = Rect.fromCenter(center: c, width: side, height: side * 0.86);
    final mountain = Paint()
      ..color = hint.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(img.left + img.width * 0.18, img.bottom - img.height * 0.22)
      ..lineTo(img.left + img.width * 0.42, img.top + img.height * 0.34)
      ..lineTo(img.left + img.width * 0.60, img.bottom - img.height * 0.34)
      ..lineTo(img.left + img.width * 0.74, img.top + img.height * 0.46)
      ..lineTo(img.left + img.width * 0.86, img.bottom - img.height * 0.22);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(img, const Radius.circular(10)),
    );
    canvas.drawPath(path, mountain);
    canvas.restore();

    // 两指张开：指尖间虚线随距离拉伸
    final f1 = c + Offset(-d, -d * 0.55);
    final f2 = c + Offset(d, d * 0.55);
    _dashLine(canvas, f1, f2, color, 0.28 + 0.25 * _bell);
    _finger(canvas, f1, s: 0.78, rotate: -0.30);
    _finger(canvas, f2, s: 0.78, rotate: -0.30 + math.pi);
  }

  /// 底部弹层下拉关闭：弹层下移 + 旁侧向下虚线箭头
  void _paintSheetDrag(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.66;
    final h = size.height * 0.32;
    final dy = _move * size.height * 0.24;
    final rect = Rect.fromLTWH(
      c.dx - w / 2,
      size.height - h - 2 + dy,
      w,
      h,
    );
    _ghost(canvas, rect, alpha: 0.12);
    // 弹层内容条
    final bar = Paint()..color = hint.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 9, rect.top + 16, w - 18, 3.4),
        const Radius.circular(2),
      ),
      bar,
    );
    // 顶部抓手条
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.center.dx, rect.top + 7),
          width: 22,
          height: 3.5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.55),
    );

    // 旁侧向下的虚线箭头
    final ax = rect.right + 9;
    _dashLine(
      canvas,
      Offset(ax, rect.top + 4),
      Offset(ax, rect.top + 4 + 14 * _bell + 6),
      color,
      0.30 + 0.25 * _bell,
    );
    _arrowHead(
      canvas,
      Offset(ax, rect.top + 4 + 14 * _bell + 6),
      const Offset(0, 1),
      color,
      0.30 + 0.45 * _bell,
    );

    _finger(canvas, Offset(rect.center.dx, rect.top + 22), s: 0.84);
  }

  /// 下拉刷新：列表下拉 + 顶部转圈
  void _paintPullDown(Canvas canvas, Size size, Offset c) {
    final w = size.width * 0.60;
    final rowH = size.height * 0.12;
    final dy = _move * size.height * 0.24;
    for (var i = 0; i < 3; i++) {
      _ghost(
        canvas,
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - rowH + i * (rowH + 5) + dy),
          width: w,
          height: rowH * 0.72,
        ),
        alpha: 0.12,
        radius: 6,
        tint: hint,
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
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    _finger(canvas, c + Offset(0, dy + 2), s: 0.84);
  }
}
