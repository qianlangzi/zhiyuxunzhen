import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_motion.dart';

/// 骨架占位行
class ZySkeletonLine extends StatelessWidget {
  const ZySkeletonLine({
    super.key,
    this.height = 12,
    this.width = double.infinity,
    this.radius,
  });

  final double height;
  final double width;
  final double? radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '内容加载中',
        child: AnimatedOpacity(
          opacity: 1,
          duration: AppMotion.fast(context),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius:
                  BorderRadius.circular(radius ?? AppDimens.radiusStatus),
            ),
          ),
        ),
      );
}

/// 骨架占位块
class ZySkeletonBlock extends StatelessWidget {
  const ZySkeletonBlock({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppDimens.radiusCard,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '内容加载中',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}
