import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

class ZyCard extends StatelessWidget {
  const ZyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.cardPadding),
    this.margin,
    this.onTap,
    this.backgroundColor = AppColors.card,
    this.borderRadius = AppDimens.radiusCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(borderRadius);
    final Widget content = Padding(padding: padding, child: child);
    final Widget card = Material(
      color: backgroundColor,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: br,
        side: const BorderSide(color: AppColors.rule, width: 1),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimens.touchTarget,
                ),
                child: content,
              ),
            ),
    );

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
