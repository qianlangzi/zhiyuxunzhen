import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

class ClinicalHeader extends StatelessWidget {
  const ClinicalHeader({
    super.key,
    required this.productName,
    required this.title,
    this.caseId,
    this.dateLabel,
    this.identityLabel,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.pagePadding,
      AppDimens.grid4,
      AppDimens.pagePadding,
      AppDimens.grid3,
    ),
  });

  final String productName;
  final String title;
  final String? caseId;
  final String? dateLabel;
  final String? identityLabel;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final List<Widget> meta = <Widget>[
      if (caseId != null)
        Text(
          caseId!,
          style: AppTextStyles.data.copyWith(color: AppColors.action),
        ),
      if (dateLabel != null)
        Text(
          dateLabel!,
          style: AppTextStyles.data.copyWith(color: AppColors.weak),
        ),
      if (identityLabel != null)
        Text(
          identityLabel!,
          style: AppTextStyles.data.copyWith(color: AppColors.weak),
        ),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  productName,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontFamily: AppTextStyles.headingFontFamily,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const Divider(height: AppDimens.grid4, color: AppColors.ink),
          if (meta.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: AppDimens.grid2,
              runSpacing: AppDimens.grid,
              children: meta,
            ),
            const SizedBox(height: AppDimens.grid2),
          ],
          Text(title, style: AppTextStyles.h1),
        ],
      ),
    );
  }
}

class ClinicalSectionHeader extends StatelessWidget {
  const ClinicalSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? description;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimens.grid3,
            runSpacing: AppDimens.grid,
            children: <Widget>[
              Text(title, style: AppTextStyles.title),
              if (action != null) action!,
            ],
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: AppDimens.grid),
            Text(description!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppDimens.grid2),
          const Divider(height: 1, color: AppColors.ink),
        ],
      ),
    );
  }
}
