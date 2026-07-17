import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

/// Compact status marker or filter control.
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

    final BorderRadius borderRadius =
        BorderRadius.circular(AppDimens.radiusStatus);
    final Widget marker = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.rule, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: style.fg),
            const SizedBox(width: AppDimens.grid),
          ],
          Text(
            label,
            style: AppTextStyles.tag.copyWith(
              fontSize: fontSize,
              color: style.fg,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return marker;

    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: borderRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: (AppDimens.touchTarget - h) / 2,
            ),
            child: marker,
          ),
        ),
      ),
    );
  }

  _ChipStyle _styleFor(ZyChipTone t) {
    switch (t) {
      case ZyChipTone.brand:
        return _ChipStyle(
          fg: AppColors.action,
          bg: AppColors.actionSoft,
        );
      case ZyChipTone.aqua:
        return _ChipStyle(
          fg: AppColors.action,
          bg: AppColors.actionSoft,
        );
      case ZyChipTone.neutral:
        return _ChipStyle(
          fg: AppColors.graphite,
          bg: AppColors.surface,
        );
      case ZyChipTone.success:
        return _ChipStyle(
          fg: AppColors.success,
          bg: AppColors.successSoft,
        );
      case ZyChipTone.warning:
        return _ChipStyle(
          fg: AppColors.warning,
          bg: AppColors.warningSoft,
        );
      case ZyChipTone.danger:
        return _ChipStyle(
          fg: AppColors.risk,
          bg: AppColors.riskSoft,
        );
    }
  }
}

class _ChipStyle {
  const _ChipStyle({
    required this.fg,
    required this.bg,
  });

  final Color fg;
  final Color bg;
}
