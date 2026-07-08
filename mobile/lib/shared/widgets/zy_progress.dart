import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 线性进度条：贴合品牌色
class ZyProgress extends StatelessWidget {
  const ZyProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.showLabel = false,
    this.label,
  });

  /// 0~1
  final double value;
  final double height;
  final bool showLabel;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabel) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                label ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Text(
                '${(v * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.grid2),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: LinearProgressIndicator(
            value: v,
            minHeight: height,
            backgroundColor: const Color(0x1A0F766E),
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }
}
