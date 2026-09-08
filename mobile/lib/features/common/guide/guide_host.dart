import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guide_controller.dart';
import 'guide_tours.dart';

/// 引导触发器 —— 包在 Shell 外层，Tab 切换时自动播放对应引导
///
/// 本身不渲染任何东西（直接返回 child），只负责在合适时机调用
/// [GuideController.enterTab]；真正的遮罩层 [GuideOverlay] 挂在
/// [MaterialApp] 的 builder 上，因此 push 出去的页面也能被覆盖。
///
/// 延迟 520ms 再播：等 Tab 转场动画和列表首屏渲染完成，否则量到的
/// 锚点位置还是上一帧的，洞会飘。等待期内若又发生切换，用 token 作废旧任务，
/// 并在回调里重新读取当前 index —— 防止「切快了播错 Tab」。
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
  int _token = 0;

  @override
  void initState() {
    super.initState();
    ref
        .read(guideControllerProvider.notifier)
        .bindTabResolver(_resolveCurrentTab);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant GuideHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) _schedule();
  }

  @override
  void dispose() {
    ref.read(guideControllerProvider.notifier).unbindTabResolver();
    super.dispose();
  }

  String _resolveCurrentTab() =>
      GuideTours.tabIdOf(widget.role, widget.currentIndex);

  void _schedule() {
    final token = ++_token;
    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted || token != _token) return;
      // 重新读一次：等待期间用户可能已经切到了别的 Tab
      ref
          .read(guideControllerProvider.notifier)
          .enterTab(widget.role, _resolveCurrentTab());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
