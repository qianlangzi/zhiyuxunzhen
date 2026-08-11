import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// 底部导航 Tab 定义
class TabItem {
  const TabItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// 学生端底部 tab（仅供 Shell 使用）
const studentTabs = [
  TabItem(label: '学习', icon: Icons.home_outlined),
  TabItem(label: '问诊', icon: Icons.chat_bubble_outline),
  TabItem(label: '错题', icon: Icons.description_outlined),
  TabItem(label: '我的', icon: Icons.person_outline),
];

/// 教师端底部 tab（仅供 Shell 使用）
const teacherTabs = [
  TabItem(label: '工作台', icon: Icons.home_outlined),
  TabItem(label: '配置', icon: Icons.settings_outlined),
  TabItem(label: '广场', icon: Icons.storefront_outlined),
  TabItem(label: '我的', icon: Icons.person_outline),
];

/// 通用底部导航栏 —— 带滑动指示条 + 颜色过渡动画
///
/// 由 Shell 持有并常驻，切换 tab 时同一个滑块平滑滑动到目标位置。
class AppBottomTabBar extends StatefulWidget {
  const AppBottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TabItem> tabs;

  @override
  State<AppBottomTabBar> createState() => _AppBottomTabBarState();
}

class _AppBottomTabBarState extends State<AppBottomTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 320),
    vsync: this,
    // 值域必须覆盖所有 tab（默认 [0,1] 会把 2/3 号 tab 的滑块钳制在 1 号位）
    lowerBound: 0,
    upperBound: (widget.tabs.length - 1).toDouble(),
    value: widget.currentIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant AppBottomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.animateTo(
        widget.currentIndex.toDouble(),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final tabCount = widget.tabs.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
      padding: EdgeInsets.only(top: 6, bottom: bottomPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabCount;
          // 指示条宽度：占单个 tab 宽度的 56%
          final indicatorWidth = tabWidth * 0.56;
          const indicatorHeight = 48.0;

          return SizedBox(
            height: indicatorHeight,
            child: Stack(
              children: [
                // —— 滑动指示条（偏方 · 浅色）——
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // 当前滑动位置 = 动画值 × 单 tab 宽度
                    final pos = _controller.value * tabWidth;
                    final left = pos + (tabWidth - indicatorWidth) / 2;
                    return Positioned(
                      left: left,
                      top: 0,
                      height: indicatorHeight,
                      width: indicatorWidth,
                      child: child!,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mossTintOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                // —— Tab 项 ——
                Row(
                  children: List.generate(tabCount, (i) {
                    final tab = widget.tabs[i];
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onTap(i),
                        child: _AnimatedTabItem(
                          icon: tab.icon,
                          label: tab.label,
                          isActive: i == widget.currentIndex,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 单个 Tab 项 —— 图标和文字颜色平滑过渡 + 轻微缩放
class _AnimatedTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _AnimatedTabItem({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    // 选中态：主色文字；未选中：灰色文字
    final activeColor = AppColors.primaryOf(context);
    final inactiveColor = AppColors.text4Of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标：颜色过渡 + 轻微放大
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isActive ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          builder: (context, t, child) {
            final color = Color.lerp(inactiveColor, activeColor, t)!;
            return Transform.scale(
              scale: 1.0 + t * 0.08,
              child: Icon(icon, size: 22, color: color),
            );
          },
        ),
        const SizedBox(height: 4),
        // 文字：颜色过渡
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isActive ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          builder: (context, t, child) {
            final color = Color.lerp(inactiveColor, activeColor, t)!;
            return Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                letterSpacing: 0.04,
              ),
            );
          },
        ),
      ],
    );
  }
}