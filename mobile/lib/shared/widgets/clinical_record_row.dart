import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import 'clinical_evidence_axis.dart';

class ClinicalRecordRow extends StatelessWidget {
  const ClinicalRecordRow({
    super.key,
    required this.leadingLabel,
    required this.title,
    required this.statusLabel,
    this.statusTone = ClinicalEvidenceTone.neutral,
    this.subtitle,
    this.onTap,
    this.showDivider = true,
  });

  final String leadingLabel;
  final String title;
  final String statusLabel;
  final ClinicalEvidenceTone statusTone;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = clinicalToneColor(statusTone);
    final String semanticsLabel = <String>[
      leadingLabel,
      title,
      if (subtitle != null) subtitle!,
      statusLabel,
    ].join('，');

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.grid3,
              ),
              decoration: BoxDecoration(
                border: showDivider
                    ? const Border(
                        bottom: BorderSide(color: AppColors.rule, width: 1),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 76,
                    child: Text(
                      leadingLabel,
                      style: AppTextStyles.data.copyWith(
                        color: AppColors.weak,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.grid2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: AppTextStyles.bodyStrong),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: AppDimens.grid),
                          Text(subtitle!, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.grid2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 72),
                    child: Text(
                      statusLabel,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.data.copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
