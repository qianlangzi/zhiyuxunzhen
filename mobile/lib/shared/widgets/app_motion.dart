import 'package:flutter/material.dart';

/// 轻量「进入显现」动效 —— 内容自上而下轻上移 + 淡入（easeOutCubic）。
///
/// 克制、不喧宾夺主：作为二级页/列表区块首次展示时的一点点灵动感，
/// 延续首页那种「活」的气息，但压低幅度避免廉价感。仅首次展示播放，
/// 后续 setState 重建时（如下拉刷新）state 保留、不重播。
class AppReveal extends StatefulWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 440),
    this.rise = 16,
  });

  final Widget child;

  /// 首播的延迟（用于列表逐项形成轻微的错落节奏）
  final Duration delay;

  final Duration duration;

  /// 上浮起始距离（px）
  final double rise;

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    final wait = widget.delay;
    if (wait == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(wait, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            // 上浮由 rise 逐渐归零
            offset: Offset(0, widget.rise * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
