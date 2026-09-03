import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

/// AI 文本打字机组件（ChatGPT 观感）· 全 app 复用
///
/// 场景：AI 一次性生成的文本（错题归因 / 学习路径 / 推荐 / 学情诊断 /
/// 备课教学设计等）到手后，按打字机节奏逐字打出，而不是整段瞬间弹出。
///
/// - 短文本（≤ maxDuration/charDelay 步数）严格逐字；长文本自适应步长，
///   总时长压缩到 [maxDuration] 内，避免几百字要等十几秒。
/// - 打字过程中末尾带 ▌ 光标，打完自动消失。
/// - [text] 变化时自动重新播放（didUpdateWidget）。
///
/// 用法：把原来的 `Text(aiText, style: ...)` 换成
/// `TypewriterText(aiText, style: ...)` 即可。
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.charDelay = const Duration(milliseconds: 16),
    this.maxDuration = const Duration(milliseconds: 1600),
    this.showCursor = true,
    this.cursorColor,
    this.onFinished,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// 每步间隔（打字节奏）
  final Duration charDelay;

  /// 长文本的最长播放总时长（自适应步长用）
  final Duration maxDuration;

  final bool showCursor;
  final Color? cursorColor;
  final VoidCallback? onFinished;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _visible = 0;
  int _total = 0;
  int _step = 1;
  bool _done = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _timer?.cancel();
    _total = widget.text.characters.length;
    if (_total == 0) {
      _done = true;
      _visible = 0;
      return;
    }
    final ticks =
        (widget.maxDuration.inMilliseconds / widget.charDelay.inMilliseconds)
            .floor();
    _step = _total <= ticks ? 1 : (_total / ticks).ceil();
    _visible = 0;
    _done = false;
    _timer = Timer.periodic(widget.charDelay, _tick);
  }

  void _tick(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    setState(() {
      _visible += _step;
      if (_visible >= _total) {
        _visible = _total;
        _done = true;
        t.cancel();
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown =
        _visible <= 0 ? '' : widget.text.characters.take(_visible).toString();
    final typing = !_done && widget.showCursor;
    return Text.rich(
      TextSpan(
        text: shown,
        style: widget.style,
        children: [
          if (typing)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _BlinkCursor(
                color: widget.cursorColor ??
                    widget.style?.color ??
                    DefaultTextStyle.of(context).style.color ??
                    Colors.grey,
                fontSize: widget.style?.fontSize ?? 13,
              ),
            ),
        ],
      ),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: _done ? widget.overflow : TextOverflow.clip,
    );
  }
}

/// 打字光标：竖条 + 透明度呼吸
class _BlinkCursor extends StatefulWidget {
  const _BlinkCursor({required this.color, required this.fontSize});

  final Color color;
  final double? fontSize;

  @override
  State<_BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<_BlinkCursor> {
  late final Timer _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (widget.fontSize ?? 13) + 2;
    return Opacity(
      opacity: _on ? 0.85 : 0.15,
      child: Container(
        width: 2,
        height: h,
        margin: const EdgeInsets.only(left: 1.5),
        color: widget.color,
      ),
    );
  }
}
