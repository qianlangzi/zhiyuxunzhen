import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_motion.dart';

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
        color: AppColors.surface,
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
                        AnimatedContainer(
                          key:
                              active ? const Key('bottom-tab-indicator') : null,
                          duration: AppMotion.fast(context),
                          curve: AppMotion.standardCurve,
                          width: 36,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.brandSoft
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusCard),
                          ),
                          child: Icon(
                            active ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: active ? AppColors.brand : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.brand : AppColors.muted,
                          ),
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
