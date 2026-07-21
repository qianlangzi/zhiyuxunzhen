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
  const CaseDetailPage({
    super.key,
    required this.caseId,
    this.scheduleId,
  });

  final String caseId;
  final int? scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CaseModel?> detail = scheduleId == null
        ? ref.watch(caseDetailProvider(caseId))
        : ref.watch(dailyCaseProvider);
    return detail.when(
      loading: () => const Scaffold(
        appBar: ZyAppBar(title: '病例详情'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        appBar: const ZyAppBar(title: '病例详情'),
        body: ZyErrorState(
          title: '病例加载失败',
          message: error.toString(),
          actionLabel: '重新加载',
          onRetry: () => ref.invalidate(caseDetailProvider(caseId)),
        ),
      ),
      data: (CaseModel? caseItem) => caseItem == null
          ? Scaffold(
              appBar: const ZyAppBar(title: '病例详情'),
              body: ZyErrorState(
                title: '病例不可用',
                message: '病例不存在或已下架',
                actionLabel: '返回病例列表',
                onRetry: () => context.go('/student/cases'),
              ),
            )
          : _buildDetail(context, caseItem),
    );
  }

  Widget _buildDetail(BuildContext context, CaseModel caseItem) {
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
                if (caseItem.chief.isNotEmpty)
                  _DetailRow(label: '主诉', value: caseItem.chief),
                _DetailRow(label: '科室', value: caseItem.department),
                _DetailRow(label: '难度', value: caseItem.difficulty),
                if (caseItem.duration.isNotEmpty)
                  _DetailRow(label: '预计用时', value: caseItem.duration),
                const SizedBox(height: AppDimens.grid6),
                const ClinicalSectionHeader(title: '训练目标'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.grid4,
                  ),
                  child: Text(
                    caseItem.tags.isEmpty
                        ? '进入问诊后逐步收集诊断依据'
                        : caseItem.tags.join('、'),
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
                if (scheduleId != null && caseItem.options.isNotEmpty)
                  _DailyAnswerSection(caseItem: caseItem),
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

class _DailyAnswerSection extends ConsumerStatefulWidget {
  const _DailyAnswerSection({required this.caseItem});

  final CaseModel caseItem;

  @override
  ConsumerState<_DailyAnswerSection> createState() =>
      _DailyAnswerSectionState();
}

class _DailyAnswerSectionState extends ConsumerState<_DailyAnswerSection> {
  String? _answer;
  bool _submitting = false;
  Map<String, dynamic>? _result;

  Future<void> _submit() async {
    if (_answer == null || widget.caseItem.scheduleId == null) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(caseRepositoryProvider).submitDaily(
            scheduleId: widget.caseItem.scheduleId!,
            answer: _answer!,
          );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('提交失败：$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.grid5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ClinicalSectionHeader(
            title: '每日一例答题',
            description: '选择答案后提交，服务端会保存本次结果。',
          ),
          ...widget.caseItem.options.map((option) => RadioListTile<String>(
                value: option,
                groupValue: _answer,
                title: Text(option),
                onChanged: _result == null
                    ? (value) => setState(() => _answer = value)
                    : null,
              )),
          if (_result == null)
            FilledButton(
              onPressed: _answer == null || _submitting ? null : _submit,
              child: Text(_submitting ? '提交中…' : '提交答案'),
            )
          else
            ClinicalEvidenceAxis(nodes: <ClinicalEvidenceNode>[
              ClinicalEvidenceNode(
                label: _result!['correct'] == true ? '回答正确' : '已完成评估',
                detail: _result!['explanation']?.toString() ?? '结果已保存',
                statusLabel: _result!['degraded'] == true ? '降级评估' : '已评估',
                tone: _result!['correct'] == true
                    ? ClinicalEvidenceTone.success
                    : ClinicalEvidenceTone.action,
              ),
            ]),
        ],
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
