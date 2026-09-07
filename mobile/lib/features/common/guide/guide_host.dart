import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guide_controller.dart';
import 'guide_tours.dart';

/// 引导触发器 —— 包在 Shell 外层，按 Tab 切换自动播放对应引导
///
/// 本身不渲染任何东西（直接返回 child），只负责在合适的时机调用
/// [GuideController.enterTab]；真正的遮罩层 [GuideOverlay] 挂在
/// [MaterialApp] 的 builder 上，因此 push 出去的页面也能被覆盖。
///
/// 延迟 520ms 再播：等 Tab 转场动画和列表首屏渲染完成，
/// 否则量到的锚点位置还是上一帧的，洞会飘。
class GuideHost extends ConsumerStatefulWidget {
  const GuideHost({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.child,
  });

  final GuideRole role;
  final int currentIndex;
  final Widget child;

  @override
  ConsumerState<GuideHost> createState() => _GuideHostState();
}

class _GuideHostState extends ConsumerState<GuideHost> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant GuideHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) _schedule();
  }

  void _schedule() {
    final tabId = GuideTours.tabIdOf(widget.role, widget.currentIndex);
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      ref.read(guideControllerProvider.notifier).enterTab(widget.role, tabId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
