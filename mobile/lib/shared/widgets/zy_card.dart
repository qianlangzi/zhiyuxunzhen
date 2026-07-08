import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 通用卡片：白色背景 + 1px 玻璃舱描边 + 柔和阴影
class ZyCard extends StatelessWidget {
  const ZyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.cardPadding),
    this.margin,
    this.onTap,
    this.backgroundColor = AppColors.card,
    this.borderRadius = AppDimens.radiusLg,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: br,
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: showShadow ? AppColors.shadowCard : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
