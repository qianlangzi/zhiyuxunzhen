import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 标签 / Chip
/// 对齐 Web 端 el-tag plain 风格
enum ZyChipTone {
  brand,
  aqua,
  neutral,
  success,
  warning,
  danger,
}

class ZyChip extends StatelessWidget {
  const ZyChip(
    this.label, {
    super.key,
    this.tone = ZyChipTone.brand,
    this.icon,
    this.onTap,
    this.small = false,
  });

  final String label;
  final ZyChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final _ChipStyle style = _styleFor(tone);
    final double h = small ? 22 : 24;
    final double fontSize = small ? 11 : 12;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusStatus),
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(
            horizontal: small ? 6 : 8,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: BorderRadius.circular(AppDimens.radiusStatus),
            border: style.border
                ? Border.all(color: style.borderColor, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 12, color: style.fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: style.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ChipStyle _styleFor(ZyChipTone t) {
    switch (t) {
      case ZyChipTone.brand:
        return _ChipStyle(
          fg: AppColors.brandStrong,
          bg: AppColors.brandSoft,
          border: false,
        );
      case ZyChipTone.aqua:
        return _ChipStyle(
          fg: AppColors.brandStrong,
          bg: AppColors.aquaSoft,
          border: false,
        );
      case ZyChipTone.neutral:
        return _ChipStyle(
          fg: AppColors.muted,
          bg: const Color(0x14000000),
          border: true,
          borderColor: AppColors.line,
        );
      case ZyChipTone.success:
        return _ChipStyle(
          fg: AppColors.brandStrong,
          bg: AppColors.brandSoft,
          border: false,
        );
      case ZyChipTone.warning:
        return _ChipStyle(
          fg: AppColors.warning,
          bg: AppColors.amberSoft,
          border: false,
        );
      case ZyChipTone.danger:
        return _ChipStyle(
          fg: AppColors.danger,
          bg: AppColors.dangerSoft,
          border: false,
        );
    }
  }
}

class _ChipStyle {
  _ChipStyle({
    required this.fg,
    required this.bg,
    required this.border,
    this.borderColor = AppColors.line,
  });

  final Color fg;
  final Color bg;
  final bool border;
  final Color borderColor;
}
