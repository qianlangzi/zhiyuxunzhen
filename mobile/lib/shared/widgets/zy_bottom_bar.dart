import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 底部导航 Tab 定义
class ZyTabSpec {
  const ZyTabSpec({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// 玻璃舱风格底部导航条
/// - 白底 + 顶部 1px 描边
/// - 选中态：品牌色 + 图标缩放动画
class ZyBottomBar extends StatelessWidget {
  const ZyBottomBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<ZyTabSpec> tabs;
  final int currentIndex;
  final ValueChanged<ZyTabSpec> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.navBarHeight,
          child: Row(
            children: List<Widget>.generate(tabs.length, (int i) {
              final ZyTabSpec tab = tabs[i];
              final bool active = i == currentIndex;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(tab),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder:
                              (Widget child, Animation<double> anim) {
                            return ScaleTransition(
                              scale: anim,
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            active ? tab.activeIcon : tab.icon,
                            key: ValueKey<String>('${tab.path}-$active'),
                            size: 24,
                            color: active
                                ? AppColors.brand
                                : AppColors.soft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.brandStrong
                                : AppColors.soft,
                          ),
                          child: Text(tab.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
