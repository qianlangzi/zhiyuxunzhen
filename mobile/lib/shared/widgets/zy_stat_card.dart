import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 数据统计卡片
class ZyStatCard extends StatelessWidget {
  const ZyStatCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.tone = StatTone.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final String? detail;
  final StatTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.grid4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.line, width: 1),
            boxShadow: AppColors.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppDimens.grid3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _valueColor(),
                  height: 1,
                ),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: AppDimens.grid2),
                Text(
                  detail!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _valueColor() {
    switch (tone) {
      case StatTone.neutral:
        return AppColors.ink;
      case StatTone.brand:
        return AppColors.brand;
      case StatTone.warning:
        return AppColors.warning;
      case StatTone.danger:
        return AppColors.danger;
    }
  }
}

enum StatTone { neutral, brand, warning, danger }
