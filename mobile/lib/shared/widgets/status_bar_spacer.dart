import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 模拟手机状态栏（仅原型展示用，真实 App 使用 SystemUiOverlayStyle）
class StatusBarSpacer extends StatelessWidget {
  const StatusBarSpacer({
    super.key,
    this.time = '9:08',
    this.dark = true,
  });

  final String time;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColorsInk.ink : AppColorsInk.paper;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 24, right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Row(
            children: [
              _SignalBars(dark: dark),
              const SizedBox(width: 5),
              _WifiIcon(dark: dark),
              const SizedBox(width: 5),
              _BatteryIcon(dark: dark),
            ],
          ),
        ],
      ),
    );
  }
}

class AppColorsInk {
  static const ink = Color(0xFF1A1F1C);
  static const paper = Color(0xFFF5F1E8);
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColorsInk.ink : AppColorsInk.paper;
    return SizedBox(
      width: 14,
      height: 10,
      child: CustomPaint(
        painter: _SignalBarsPainter(color),
      ),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  final Color color;
const   _SignalBarsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bars = [0.4, 0.6, 0.8, 1.0];
    final barWidth = 2.0;
    final gap = 2.0;
    for (var i = 0; i < 4; i++) {
      final h = size.height * bars[i];
      canvas.drawRect(
        Rect.fromLTWH(
          i * (barWidth + gap),
          size.height - h,
          barWidth,
          h,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WifiIcon extends StatelessWidget {
  const _WifiIcon({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColorsInk.ink : AppColorsInk.paper;
    return SizedBox(
      width: 14,
      height: 10,
      child: CustomPaint(painter: _WifiPainter(color)),
    );
  }
}

class _WifiPainter extends CustomPainter {
  final Color color;
const   _WifiPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // Three arcs
    canvas.drawArc(
      Rect.fromLTWH(1, 3, 12, 8),
      3.5,
      2.8,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(3, 5, 8, 6),
      3.5,
      2.8,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height - 1.5), 1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColorsInk.ink : AppColorsInk.paper;
    return SizedBox(
      width: 20,
      height: 10,
      child: CustomPaint(painter: _BatteryPainter(color)),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final Color color;
const   _BatteryPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Battery body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 0.5, 16, 9),
        const Radius.circular(2),
      ),
      paint,
    );
    // Battery fill
    paint.style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(2, 2, 11, 6), paint);
    // Battery tip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 3, 2, 4),
        const Radius.circular(0.5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
