import 'package:flutter/material.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/widgets.dart';

/// 可拖动批阅详情层；教师意见仅保留在当前详情会话。
class ReviewDetailSheet extends StatefulWidget {
  const ReviewDetailSheet({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReturn,
  });

  final ReviewItem item;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  @override
  State<ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<ReviewDetailSheet> {
  late final TextEditingController _opinionController;

  @override
  void initState() {
    super.initState();
    _opinionController = TextEditingController();
  }

  @override
  void dispose() {
    _opinionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReviewItem item = widget.item;
    final String opinion = _opinionController.text.trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusSheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.grid6,
              ),
              children: <Widget>[
                const _DragHandle(),
                Text('批阅详情', style: AppTextStyles.h2),
                const SizedBox(height: AppDimens.grid),
                Text(
                  '${item.student} · ${item.assignment}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppDimens.grid5),
                const ClinicalSectionHeader(
                  title: '复核证据',
                  description: '仅呈现当前批阅记录已有信息',
                ),
                const SizedBox(height: AppDimens.grid2),
                ClinicalEvidenceAxis(
                  nodes: <ClinicalEvidenceNode>[
                    ClinicalEvidenceNode(
                      label: '问题记录',
                      detail: item.issue,
                      statusLabel: _issueStatus(item.status),
                      tone: _statusTone(item.status),
                    ),
                    ClinicalEvidenceNode(
                      label: '评分记录',
                      detail: '评分 ${item.score} 分',
                      statusLabel: '已记录',
                      tone: ClinicalEvidenceTone.neutral,
                    ),
                    ClinicalEvidenceNode(
                      label: '当前状态',
                      detail: item.status,
                      statusLabel: item.status,
                      tone: _statusTone(item.status),
                    ),
                    ClinicalEvidenceNode(
                      label: '教师意见',
                      detail: opinion.isEmpty ? '尚未填写' : opinion,
                      statusLabel: opinion.isEmpty ? '待填写' : '已记录',
                      tone: opinion.isEmpty
                          ? ClinicalEvidenceTone.neutral
                          : ClinicalEvidenceTone.action,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.grid5),
                TextField(
                  key: const ValueKey<String>('review-opinion-field'),
                  controller: _opinionController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: '教师意见（可选）',
                    hintText: '记录本次复核判断',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (String _) => setState(() {}),
                ),
                const SizedBox(height: AppDimens.grid5),
                OutlinedButton(
                  onPressed: widget.onReturn,
                  child: const Text('退回修改'),
                ),
                const SizedBox(height: AppDimens.grid3),
                FilledButton(
                  onPressed: widget.onApprove,
                  child: const Text('通过'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '拖动批阅详情',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ruleStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

String _issueStatus(String status) {
  switch (status) {
    case '有争议项':
      return '需确认';
    case '待复核':
      return '待复核';
    case '已复核':
      return '已确认';
    default:
      return '已记录';
  }
}

ClinicalEvidenceTone _statusTone(String status) {
  switch (status) {
    case '有争议项':
    case '待修改':
      return ClinicalEvidenceTone.risk;
    case '待复核':
      return ClinicalEvidenceTone.action;
    case '已复核':
      return ClinicalEvidenceTone.success;
    default:
      return ClinicalEvidenceTone.neutral;
  }
}
