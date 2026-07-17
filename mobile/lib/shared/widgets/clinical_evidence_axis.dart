import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';

enum ClinicalEvidenceTone { neutral, action, risk, success }

@immutable
class ClinicalEvidenceNode {
  const ClinicalEvidenceNode({
    required this.label,
    required this.detail,
    required this.statusLabel,
    this.tone = ClinicalEvidenceTone.neutral,
  });

  final String label;
  final String detail;
  final String statusLabel;
  final ClinicalEvidenceTone tone;
}

class ClinicalEvidenceAxis extends StatelessWidget {
  const ClinicalEvidenceAxis({
    super.key,
    required this.nodes,
    this.padding = EdgeInsets.zero,
  });

  final List<ClinicalEvidenceNode> nodes;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List<Widget>.generate(nodes.length, (int index) {
          final ClinicalEvidenceNode node = nodes[index];
          return _EvidenceRow(
            node: node,
            showLineBelow: index != nodes.length - 1,
          );
        }),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.node, required this.showLineBelow});

  final ClinicalEvidenceNode node;
  final bool showLineBelow;

  @override
  Widget build(BuildContext context) {
    final Color color = clinicalToneColor(node.tone);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                if (showLineBelow)
                  Positioned(
                    top: 12,
                    bottom: 0,
                    child: Container(width: 1, color: AppColors.ruleStrong),
                  ),
                Positioned(
                  top: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: node.tone == ClinicalEvidenceTone.risk
                          ? color
                          : AppColors.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.grid2,
                AppDimens.grid2,
                0,
                AppDimens.grid3,
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.only(bottom: AppDimens.grid3),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.rule, width: 1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(node.label, style: AppTextStyles.bodyStrong),
                          const SizedBox(height: AppDimens.grid),
                          Text(node.detail, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.grid2),
                    Semantics(
                      label: node.statusLabel,
                      child: ExcludeSemantics(
                        child: Text(
                          node.statusLabel,
                          style: AppTextStyles.data.copyWith(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color clinicalToneColor(ClinicalEvidenceTone tone) {
  switch (tone) {
    case ClinicalEvidenceTone.neutral:
      return AppColors.graphite;
    case ClinicalEvidenceTone.action:
      return AppColors.action;
    case ClinicalEvidenceTone.risk:
      return AppColors.risk;
    case ClinicalEvidenceTone.success:
      return AppColors.success;
  }
}
