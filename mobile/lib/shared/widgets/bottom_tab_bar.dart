import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// 底部导航 Tab 定义
class TabItem {
  const TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// 学生端底部 tab（仅供 Shell 使用）
/// 4 tab：学习 / 训练（病例实训·收敛后的病例主流程）/ 成长（错题·复盘·推荐）/ 我的
const studentTabs = [
  TabItem(label: '学习', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
  TabItem(label: '训练', icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services_rounded),
  TabItem(label: '成长', icon: Icons.trending_up_outlined, activeIcon: Icons.trending_up_rounded),
  TabItem(label: '我的', icon: Icons.person_outline, activeIcon: Icons.person_rounded),
];

/// 教师端底部 tab（仅供 Shell 使用）
///
/// 4 个 tab：工作台 / 备课 / 班级 / 我的。
/// 「SP 病例广场」已浓缩进首页 SP 广场板块，「班级」取代原「广场」tab，
/// 管理我的教学班（作业 / 学情 / 资料 / 成员）。
const teacherTabs = [
  TabItem(label: '工作台', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
  TabItem(label: '备课', icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note_rounded),
  TabItem(label: '班级', icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded),
  TabItem(label: '我的', icon: Icons.person_outline, activeIcon: Icons.person_rounded),
];

/// 通用底部导航栏 —— 悬浮胶囊式 + 滑动指示 + 颜色过渡动画
///
/// 由 Shell 持有并常驻，切换 tab 时同一个滑块平滑滑动到目标位置。
/// 采用主流大厂的「悬浮浮层」风格：白色圆角容器 + 柔和阴影浮起于内容之上，
/// 选中 tab 以主色软底胶囊 + 实心图标呈现，灵动且不占额外高度。
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
    duration: const Duration(milliseconds: 360),
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
        curve: Curves.easeOutCubic,
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

    final navHeight = 72.0;

    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding + 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgOf(context).withValues(alpha: 0.0),
            AppColors.bgOf(context).withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Container(
        height: navHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.surfaceEdgeOf(context).withValues(alpha: 0.5)),
          boxShadow: AppShadow.lifted(context),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / tabCount;
            // 指示胶囊宽度：占单个 tab 的 62%
            final indicatorWidth = tabWidth * 0.62;
            final indicatorHeight = 48.0;

            return Stack(
              children: [
                // —— 滑动指示胶囊（主色软底）——
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pos = _controller.value * tabWidth;
                    final left = pos + (tabWidth - indicatorWidth) / 2;
                    return Positioned(
                      left: left,
                      top: (navHeight - indicatorHeight) / 2,
                      height: indicatorHeight,
                      width: indicatorWidth,
                      child: child!,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mossTintOf(context),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                // —— Tab 项 ——
                Positioned.fill(
                  child: Row(
                    children: List.generate(tabCount, (i) {
                      final tab = widget.tabs[i];
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(i),
                          child: _AnimatedTabItem(
                            icon: tab.icon,
                            activeIcon: tab.activeIcon,
                            label: tab.label,
                            isActive: i == widget.currentIndex,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 单个 Tab 项 —— 图标和文字颜色平滑过渡 + 轻微缩放
class _AnimatedTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;

  const _AnimatedTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primaryOf(context);
    final inactiveColor = AppColors.text4Of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 图标：颜色过渡 + 轻微放大 + 实/空心切换
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isActive ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            final color = Color.lerp(inactiveColor, activeColor, t)!;
            final IconData shownIcon = t > 0.5 ? activeIcon : this.icon;
            return Transform.scale(
              scale: 1.0 + t * 0.12,
              child: Icon(shownIcon, size: 22, color: color),
            );
          },
        ),
        const SizedBox(height: 4),
        // 文字：颜色过渡 + 选中小字重
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
                fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }
}