import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

class CaseDetailPage extends ConsumerWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository repository = ref.watch(caseRepositoryProvider);
    final CaseModel daily = repository.daily();
    final CaseModel? caseItem =
        repository.byId(caseId) ?? (daily.id == caseId ? daily : null);

    if (caseItem == null) {
      return Scaffold(
        appBar: const ZyAppBar(title: '病例详情'),
        body: ZyErrorState(
          title: '病例不可用',
          message: '病例不存在或已下架',
          actionLabel: '返回病例列表',
          onRetry: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/student/cases');
          },
        ),
      );
    }

    return Scaffold(
      appBar: const ZyAppBar(title: '病例详情'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: <Widget>[
          ClinicalHeader(
            productName: '智愈寻真',
            title: caseItem.title,
            caseId: caseItem.id,
            identityLabel: '学生训练病例',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ClinicalSectionHeader(title: '患者概况'),
                _DetailRow(label: '主诉', value: caseItem.chief),
                _DetailRow(label: '科室', value: caseItem.department),
                _DetailRow(label: '难度', value: caseItem.difficulty),
                _DetailRow(label: '预计用时', value: caseItem.duration),
                const SizedBox(height: AppDimens.grid6),
                const ClinicalSectionHeader(title: '训练目标'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.grid4,
                  ),
                  child: Text(
                    caseItem.tags.join('、'),
                    style: AppTextStyles.body,
                  ),
                ),
                if (caseItem.summary != null) ...<Widget>[
                  const SizedBox(height: AppDimens.grid3),
                  const ClinicalSectionHeader(title: '已有资料'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.grid4,
                    ),
                    child: Text(caseItem.summary!, style: AppTextStyles.body),
                  ),
                  if (caseItem.source != null)
                    _DetailRow(label: '资料来源', value: caseItem.source!),
                ],
                const SizedBox(height: AppDimens.grid6),
                const ClinicalSectionHeader(
                  title: '注意事项',
                  description: '先完成必要检查，再排除无指征项目。',
                ),
                ClinicalEvidenceAxis(
                  nodes: <ClinicalEvidenceNode>[
                    if (caseItem.requiredExam != null)
                      ClinicalEvidenceNode(
                        label: '必要检查',
                        detail: caseItem.requiredExam!,
                        statusLabel: '优先确认',
                        tone: ClinicalEvidenceTone.action,
                      ),
                    ClinicalEvidenceNode(
                      label: '问诊顺序',
                      detail: '先补齐症状演变、危险因素与既往史。',
                      statusLabel: '待完成',
                      tone: ClinicalEvidenceTone.action,
                    ),
                    if (caseItem.avoidExam != null)
                      ClinicalEvidenceNode(
                        label: '检查风险',
                        detail: caseItem.avoidExam!,
                        statusLabel: '避免滥用',
                        tone: ClinicalEvidenceTone.risk,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ZyStickyActionBar(
        child: FilledButton.icon(
          onPressed: () => context.push('/student/chat?caseId=${caseItem.id}'),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('开始问诊'),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.rule, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label, style: AppTextStyles.data),
          ),
          const SizedBox(width: AppDimens.grid2),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );
  }
}
