import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
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
              void handleTap() => onTap(tab);
              return Expanded(
                child: Semantics(
                  key: ValueKey<String>('bottom-tab-$i'),
                  label: tab.label,
                  button: true,
                  selected: active,
                  onTap: handleTap,
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: handleTap,
                      excludeFromSemantics: true,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimens.grid,
                              AppDimens.grid2,
                              AppDimens.grid,
                              AppDimens.grid3,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  active ? tab.activeIcon : tab.icon,
                                  size: 22,
                                  color: active
                                      ? AppColors.action
                                      : AppColors.graphite,
                                ),
                                const SizedBox(height: AppDimens.grid),
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.tag.copyWith(
                                    fontSize: 11,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: active
                                        ? AppColors.action
                                        : AppColors.graphite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: AnimatedContainer(
                              key: active
                                  ? const Key('bottom-tab-indicator')
                                  : null,
                              duration: AppMotion.fast(context),
                              curve: AppMotion.standardCurve,
                              width: active ? 28 : 0,
                              height: 2,
                              color: active
                                  ? AppColors.action
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
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
