import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyu/data/models.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../data/repositories/content_repository.dart';
import '../../../shared/widgets/widgets.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CaseRepository caseRepo = ref.watch(caseRepositoryProvider);
    final LearningRepository learningRepo =
        ref.watch(learningRepositoryProvider);
    final CaseModel daily = caseRepo.daily();
    final List<CaseModel> recommendedCases = caseRepo.all().take(2).toList();
    final List<MistakeItem> mistakes = learningRepo.mistakes();
    final DateTime today = DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: ClinicalHeader(
              productName: '智愈寻真',
              title: '病例训练工作台',
              dateLabel: _dateLabel(today),
              identityLabel: '学生工作区',
            ),
          ),
          SliverToBoxAdapter(child: _CurrentCaseSection(caseItem: daily)),
          SliverToBoxAdapter(child: _ReviewSection(mistakes: mistakes)),
          SliverToBoxAdapter(
            child: _RecommendedCasesSection(cases: recommendedCases),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }
}

class _CurrentCaseSection extends StatelessWidget {
  const _CurrentCaseSection({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.grid2,
        AppDimens.pagePadding,
        AppDimens.grid6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ClinicalSectionHeader(
            title: '推荐训练',
            description: '先确认已知信息，再补齐问诊证据。',
          ),
          ClinicalRecordRow(
            leadingLabel: caseItem.id,
            title: caseItem.title,
            subtitle:
                '${caseItem.department} · ${caseItem.difficulty} · 预计 ${caseItem.duration}',
            statusLabel: '可开始',
            statusTone: ClinicalEvidenceTone.action,
            onTap: () => context.push('/student/case/${caseItem.id}'),
          ),
          const SizedBox(height: AppDimens.grid3),
          ClinicalEvidenceAxis(
            nodes: <ClinicalEvidenceNode>[
              ClinicalEvidenceNode(
                label: '患者摘要',
                detail: caseItem.summary ?? caseItem.chief,
                statusLabel: '已记录',
              ),
              ClinicalEvidenceNode(
                label: '训练目标',
                detail: caseItem.tags.join('、'),
                statusLabel: '待完成',
                tone: ClinicalEvidenceTone.action,
              ),
              if (caseItem.requiredExam != null)
                ClinicalEvidenceNode(
                  label: '必要检查',
                  detail: '优先确认：${caseItem.requiredExam}',
                  statusLabel: '待确认',
                  tone: ClinicalEvidenceTone.action,
                ),
              if (caseItem.avoidExam != null)
                ClinicalEvidenceNode(
                  label: '检查风险',
                  detail: '避免无指征使用：${caseItem.avoidExam}',
                  statusLabel: '需警惕',
                  tone: ClinicalEvidenceTone.risk,
                ),
            ],
          ),
          const SizedBox(height: AppDimens.grid4),
          FilledButton.icon(
            onPressed: () => context.push('/student/case/${caseItem.id}'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('查看病例'),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.mistakes});

  final List<MistakeItem> mistakes;

  @override
  Widget build(BuildContext context) {
    final List<MistakeItem> pending =
        mistakes.where((MistakeItem item) => !item.reviewed).take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.grid6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClinicalSectionHeader(
            title: '待复盘',
            description: pending.isEmpty ? '暂无需要处理的错误依据。' : '从错误依据返回病例继续训练。',
            action: TextButton(
              onPressed: () => context.go('/student/mistakes'),
              child: const Text('查看全部'),
            ),
          ),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.grid4),
              child: Text('当前没有待复盘记录。'),
            )
          else
            for (int index = 0; index < pending.length; index++)
              ClinicalRecordRow(
                leadingLabel: '复盘 ${index + 1}',
                title: pending[index].title,
                subtitle: pending[index].evidence,
                statusLabel: '待复盘',
                statusTone: ClinicalEvidenceTone.risk,
                onTap: () => context.go('/student/mistakes'),
              ),
        ],
      ),
    );
  }
}

class _RecommendedCasesSection extends StatelessWidget {
  const _RecommendedCasesSection({required this.cases});

  final List<CaseModel> cases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClinicalSectionHeader(
            title: '推荐病例',
            action: TextButton(
              onPressed: () => context.go('/student/cases'),
              child: const Text('病例库'),
            ),
          ),
          for (final CaseModel item in cases)
            ClinicalRecordRow(
              leadingLabel: item.id,
              title: item.title,
              subtitle:
                  '${item.department} · ${item.difficulty} · ${item.duration}',
              statusLabel: '可训练',
              onTap: () => context.push('/student/case/${item.id}'),
            ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}
